import AVFoundation
import CoreVideo
import CoreGraphics

/// Writes a sequence of `CGImage`s to a silent H.264 `.mp4`.
///
/// Deliberately free of SwiftUI and UIKit: the caller renders frames (which must happen on
/// the main actor, because `ImageRenderer` is main-actor bound) and hands them here, where
/// all the AVFoundation work runs off the main thread.
///
/// `@unchecked Sendable` is honest rather than lazy — an instance is created on one actor and
/// then touched only by the single consumer task that drains frames into it. See
/// `ShareVideoRenderer.export`, the only caller.
final class VideoFrameWriter: @unchecked Sendable {

    enum WriterError: LocalizedError {
        case cannotCreateWriter
        case cannotAddInput
        case noPixelBufferPool
        case pixelBufferAllocationFailed(CVReturn)
        case cannotCreateContext
        case writeFailed(Error?)

        var errorDescription: String? {
            switch self {
            case .cannotCreateWriter:          return "Could not start the video writer."
            case .cannotAddInput:              return "Could not configure the video track."
            case .noPixelBufferPool:           return "The video writer has no frame buffer."
            case .pixelBufferAllocationFailed: return "Ran out of video frame buffers."
            case .cannotCreateContext:         return "Could not draw into a video frame."
            case .writeFailed(let error):      return error?.localizedDescription ?? "Writing the video failed."
            }
        }
    }

    private let outputURL: URL
    private let size: CGSize
    private let frameRate: Int32

    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor

    private var frameIndex: Int64 = 0

    init(outputURL: URL, size: CGSize, frameRate: Int32 = 30, bitrate: Int = 10_000_000) throws {
        self.outputURL = outputURL
        self.size = size
        self.frameRate = frameRate

        // AVAssetWriter refuses to initialise onto an existing file — so re-exporting the
        // same achievement would fail without this.
        try? FileManager.default.removeItem(at: outputURL)

        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            throw WriterError.cannotCreateWriter
        }
        self.writer = writer

        let compression: [String: Any] = [
            AVVideoAverageBitRateKey: bitrate,
            AVVideoExpectedSourceFrameRateKey: Int(frameRate),
            AVVideoMaxKeyFrameIntervalKey: Int(frameRate),          // one keyframe per second
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoAllowFrameReorderingKey: true
        ]

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: compression,
            // Tag the colour space explicitly. Without it, Instagram's and TikTok's re-encode
            // guesses, and the purple gradient comes back visibly shifted.
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ]
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        // We're a file-based source, not a camera — let the writer apply backpressure.
        input.expectsMediaDataInRealTime = false
        self.input = input

        let sourceAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
            // Makes the pool vend IOSurface-backed buffers, which the encoder can take
            // without an extra copy.
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as CFDictionary,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        self.adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
                                                            sourcePixelBufferAttributes: sourceAttributes)

        guard writer.canAdd(input) else { throw WriterError.cannotAddInput }
        writer.add(input)
    }

    /// Must be called before the first `append` — the pixel buffer pool doesn't exist until
    /// writing has started.
    func start() throws {
        guard writer.startWriting() else { throw WriterError.writeFailed(writer.error) }
        writer.startSession(atSourceTime: .zero)
    }

    /// Appends one frame at the next `1/frameRate` slot, waiting if the encoder is behind.
    func append(_ image: CGImage) async throws {
        while !input.isReadyForMoreMediaData {
            if writer.status == .failed { throw WriterError.writeFailed(writer.error) }
            try await Task.sleep(nanoseconds: 2_000_000)   // 2 ms
        }
        guard writer.status == .writing else { throw WriterError.writeFailed(writer.error) }
        guard let pool = adaptor.pixelBufferPool else { throw WriterError.noPixelBufferPool }

        let buffer = try Self.pixelBuffer(from: image, pool: pool, size: size)
        let time = CMTime(value: frameIndex, timescale: frameRate)
        guard adaptor.append(buffer, withPresentationTime: time) else {
            throw WriterError.writeFailed(writer.error)
        }
        frameIndex += 1
    }

    /// Closes the file and returns its URL.
    func finish() async throws -> URL {
        input.markAsFinished()
        // Ending the session one frame past the last PTS gives the file an exact duration;
        // without it the final frame's display length is undefined.
        writer.endSession(atSourceTime: CMTime(value: frameIndex, timescale: frameRate))
        await writer.finishWriting()
        guard writer.status == .completed else { throw WriterError.writeFailed(writer.error) }
        return outputURL
    }

    func cancel() {
        if writer.status == .writing { writer.cancelWriting() }
        try? FileManager.default.removeItem(at: outputURL)
    }

    // MARK: - CGImage → CVPixelBuffer

    /// Draws `image` into a pooled pixel buffer.
    ///
    /// Three things have to be right at once here, and each fails in its own distinctive way:
    /// the byte order (wrong ⇒ red and blue swapped, or a nil context), the row stride
    /// (wrong ⇒ the image skews diagonally), and pooling (skipped ⇒ a memory spike as every
    /// frame allocates 8 MB afresh). A fourth, the vertical flip, must *not* be applied —
    /// see the note at the `draw` call.
    private static func pixelBuffer(from image: CGImage,
                                    pool: CVPixelBufferPool,
                                    size: CGSize) throws -> CVPixelBuffer {
        var optional: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &optional)
        guard status == kCVReturnSuccess, let buffer = optional else {
            throw WriterError.pixelBufferAllocationFailed(status)
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let base = CVPixelBufferGetBaseAddress(buffer) else {
            throw WriterError.cannotCreateContext
        }

        // 32BGRA means the bytes in memory run B, G, R, A. Core Graphics describes that as a
        // little-endian 32-bit word with alpha in the first position of the word. Video is
        // opaque, so skip the alpha rather than premultiply it.
        let bitmapInfo = CGImageAlphaInfo.noneSkipFirst.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue

        guard let context = CGContext(
            data: base,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            // Pool rows are padded for alignment — this is NOT width * 4.
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else {
            throw WriterError.cannotCreateContext
        }

        // No flip. A bitmap context writes its first row of memory as the *top* row of the
        // rendered image, which is exactly where a pixel buffer expects the top row — so
        // `draw` lands upright on its own. Flipping here (the reflex, because Core Graphics
        // is bottom-left origin) is what made every exported video play upside down and
        // mirrored. The bottom-left origin does apply to the drawing *rectangle*, but the
        // rect covers the whole frame, so it makes no difference.
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))

        return buffer
    }
}
