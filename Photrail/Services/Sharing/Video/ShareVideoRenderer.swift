import SwiftUI
import CoreGraphics

/// Renders an animated share card to a silent `.mp4`.
///
/// `ImageRenderer` can't sample a `withAnimation` state flip, a `TimelineView` or a
/// `.phaseAnimator` — it captures one arbitrary phase. So an exportable animation has to be a
/// *pure function of progress*: the card is handed a `Double` in 0…1 and must derive every
/// animated property from it, with no `@State`, no `Date()` read, and no unseeded randomness.
///
/// The same purity is what lets the in-app preview drive the identical view from a
/// `TimelineView` and be guaranteed to match the exported file.
enum ShareVideoRenderer {

    struct Config {
        var duration: Double = 3.0
        var fps: Int = 30
        /// Export resolution. 1080×1920 is what Instagram and TikTok want; anything smaller
        /// gets upscaled by them and looks soft.
        var size = CGSize(width: 1080, height: 1920)
        /// Design-space size, matching every other share card in the app. The renderer scales
        /// this up by 3× — laying the card out at full pixel size instead would leave the
        /// fonts tiny and the hairlines sub-pixel.
        var baseSize = CGSize(width: 360, height: 640)

        var frameCount: Int { max(2, Int((duration * Double(fps)).rounded())) }
    }

    enum RenderError: LocalizedError {
        case frameRenderFailed
        case sizeMismatch(CGSize)

        var errorDescription: String? {
            switch self {
            case .frameRenderFailed:  return "Could not draw a frame of the video."
            case .sizeMismatch(let s): return "Frame size \(Int(s.width))×\(Int(s.height)) doesn't match the video."
            }
        }
    }

    /// Renders `card(progress)` across 0…1 and returns the finished file.
    ///
    /// Frames are produced on the main actor (`ImageRenderer` requires it) and drained by a
    /// background task that does the encoding, so the two overlap. The main actor stays busy
    /// for the duration — show a blocking progress indicator over this.
    @MainActor
    static func export<Card: View>(
        config: Config = Config(),
        outputURL: URL,
        onProgress: ((Double) -> Void)? = nil,
        @ViewBuilder card: @escaping (Double) -> Card
    ) async throws -> URL {

        let writer = try VideoFrameWriter(outputURL: outputURL,
                                          size: config.size,
                                          frameRate: Int32(config.fps))
        try writer.start()

        // Bounded so at most a few 8 MB frames are ever in flight. Unlike
        // `AsyncStream(bufferingPolicy:)`, a full queue makes the producer *wait* rather than
        // silently dropping frames — dropped frames would shorten the video on slow devices.
        let queue = FrameQueue(capacity: 3)

        let consumer = Task.detached(priority: .userInitiated) { () -> URL in
            do {
                while let image = await queue.dequeue() {
                    try await writer.append(image)
                }
                return try await writer.finish()
            } catch {
                await queue.abort()
                writer.cancel()
                throw error
            }
        }

        let total = config.frameCount
        let scale = config.size.width / config.baseSize.width

        for frame in 0..<total {
            if Task.isCancelled {
                await queue.abort()
                consumer.cancel()
                writer.cancel()
                throw CancellationError()
            }

            let progress = Double(frame) / Double(total - 1)
            let renderer = ImageRenderer(content:
                card(progress)
                    .frame(width: config.baseSize.width, height: config.baseSize.height)
            )
            renderer.scale = scale
            renderer.isOpaque = true

            guard let image = renderer.cgImage else {
                await queue.abort()
                writer.cancel()
                throw RenderError.frameRenderFailed
            }
            // A mismatch here would be encoded as a stretched or letterboxed video rather
            // than an error, so catch it on the first frame instead.
            if frame == 0,
               CGFloat(image.width) != config.size.width || CGFloat(image.height) != config.size.height {
                await queue.abort()
                writer.cancel()
                throw RenderError.sizeMismatch(CGSize(width: image.width, height: image.height))
            }

            await queue.enqueue(image)
            onProgress?(Double(frame + 1) / Double(total))
        }

        await queue.finish()
        return try await consumer.value
    }
}

// MARK: - Frame queue

/// A one-producer, one-consumer bounded queue that applies real backpressure: `enqueue`
/// suspends while the buffer is full instead of dropping the frame.
private actor FrameQueue {
    private var items: [CGImage] = []
    private var isFinished = false
    private var isAborted = false
    private let capacity: Int

    // Single producer and single consumer, so one waiter apiece is enough.
    private var waitingConsumer: CheckedContinuation<CGImage?, Never>?
    private var waitingProducer: CheckedContinuation<Void, Never>?

    init(capacity: Int) { self.capacity = max(1, capacity) }

    func enqueue(_ image: CGImage) async {
        while !isAborted && items.count >= capacity {
            await withCheckedContinuation { waitingProducer = $0 }
        }
        guard !isAborted else { return }

        if let consumer = waitingConsumer {
            waitingConsumer = nil
            consumer.resume(returning: image)
        } else {
            items.append(image)
        }
    }

    func dequeue() async -> CGImage? {
        if !items.isEmpty {
            let item = items.removeFirst()
            resumeProducer()
            return item
        }
        if isFinished || isAborted { return nil }
        return await withCheckedContinuation { waitingConsumer = $0 }
    }

    /// No more frames are coming; the consumer should drain and stop.
    func finish() {
        isFinished = true
        if let consumer = waitingConsumer {
            waitingConsumer = nil
            consumer.resume(returning: nil)
        }
    }

    /// Something failed — wake both sides so neither is left suspended forever.
    func abort() {
        isAborted = true
        items.removeAll()
        if let consumer = waitingConsumer {
            waitingConsumer = nil
            consumer.resume(returning: nil)
        }
        resumeProducer()
    }

    private func resumeProducer() {
        if let producer = waitingProducer {
            waitingProducer = nil
            producer.resume()
        }
    }
}
