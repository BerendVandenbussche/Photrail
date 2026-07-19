import Foundation
import Photos

/// Heuristic for which saved photos were most likely *captured by the user*, so biometric
/// insights (the Excitement Meter) aren't attributed to screenshots or images received from
/// other people.
///
/// Deliberately avoids device-identity comparison: EXIF `Make`/`Model` reflects the
/// *capturing* device, which (a) can't distinguish your iPhone from a friend's, and (b) is
/// meaningless after upgrading/transferring to a new phone. Instead it rules out clear
/// non-captures from `PHAsset` metadata only — no image data is loaded. Intentionally
/// lenient ("balanced"): when in doubt, a photo counts as yours.
///
/// An `actor` so the `PHAsset` enumeration runs off the main thread — it must never block UI.
actor PhotoAuthorship {

    /// The subset of `assetIDs` that look like genuine user captures.
    func likelyAuthored(assetIDs: [String]) async -> Set<String> {
        guard !assetIDs.isEmpty else { return [] }
        return await withCheckedContinuation { continuation in
            let fetched = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
            var authored = Set<String>()
            fetched.enumerateObjects { asset, _, _ in
                if Self.isLikelyCapture(asset) { authored.insert(asset.localIdentifier) }
            }
            continuation.resume(returning: authored)
        }
    }

    static func isLikelyCapture(_ asset: PHAsset) -> Bool {
        // Screenshots are never captures.
        if asset.mediaSubtypes.contains(.photoScreenshot) { return false }
        // Shared-album and iTunes-synced assets came from elsewhere.
        if asset.sourceType.contains(.typeCloudShared) || asset.sourceType.contains(.typeiTunesSynced) {
            return false
        }
        // Messaging-app / download filename patterns.
        if let name = PHAssetResource.assetResources(for: asset).first?.originalFilename,
           isForeignFilename(name) {
            return false
        }
        return true
    }

    /// Pure filename test (unit-testable without Photos). Apple camera captures are
    /// `IMG_1234.HEIC` (underscore); the patterns below are typical of received/saved images.
    static func isForeignFilename(_ filename: String) -> Bool {
        let lower = filename.lowercased()
        let foreignPrefixes = ["whatsapp", "screenshot", "fb_img", "signal-",
                               "telegram", "photo_", "received", "download"]
        if foreignPrefixes.contains(where: { lower.hasPrefix($0) }) { return true }
        // WhatsApp & similar: "img-20230101-wa0001.jpg" (dash + "-wa" marker).
        if lower.hasPrefix("img-") || lower.contains("-wa") { return true }
        // Generic saved images.
        if ["image.jpg", "image.jpeg", "image.png"].contains(lower) { return true }
        return false
    }
}
