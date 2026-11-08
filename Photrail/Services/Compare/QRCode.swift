import UIKit
import CoreImage.CIFilterBuiltins

/// QR codes from CoreImage — built in, nothing to bundle.
enum QRCode {
    /// A crisp QR code for `string`. Draw it with `.interpolation(.none)` so the modules stay
    /// sharp when scaled.
    static func image(for string: String, scale: CGFloat = 10) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        // "M": 15% error correction, a good balance for a code shown on a screen.
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?
                .transformed(by: CGAffineTransform(scaleX: scale, y: scale)),
              let cgImage = CIContext().createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
