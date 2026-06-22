import Photos
import Vision
import UIKit

/// Picks a user's "best" photos for the recap, fully on-device with the Vision framework:
/// - image **aesthetics** (iOS 18) to favor good-looking shots and drop screenshots/docs
/// - scene **classification** to match the personality (nature/coastal/…) and to
///   down-rank photos dominated by people or pets (family/dog shots).
actor PhotoCurator {

    /// Returns the top `limit` photo IDs from `candidateIDs`, best first, while
    /// spreading the picks out in time so near-duplicates from the same moment
    /// don't all appear together.
    func bestPhotos(candidateIDs: [String],
                    category: TravelCategory?,
                    limit: Int = 6,
                    minSpacing: TimeInterval = 12 * 3600) async -> [String] {
        guard !candidateIDs.isEmpty else { return [] }
        let assets = fetchAssets(candidateIDs)

        var scored: [(id: String, score: Double, date: Date)] = []
        for asset in assets {
            guard let cg = await thumbnail(for: asset)?.cgImage else { continue }
            guard let score = await score(cg: cg, isFavorite: asset.isFavorite, category: category) else { continue }
            scored.append((asset.localIdentifier, score, asset.creationDate ?? .distantPast))
        }

        let ranked = scored.sorted { $0.score > $1.score }

        // Greedy: take the best photo that's at least `minSpacing` from everything chosen.
        var chosen: [(id: String, date: Date)] = []
        for candidate in ranked {
            guard chosen.count < limit else { break }
            if chosen.allSatisfy({ abs($0.date.timeIntervalSince(candidate.date)) >= minSpacing }) {
                chosen.append((candidate.id, candidate.date))
            }
        }
        // If spacing left us short (e.g. a single short trip), backfill by score.
        if chosen.count < limit {
            let chosenIDs = Set(chosen.map(\.id))
            for candidate in ranked where !chosenIDs.contains(candidate.id) {
                guard chosen.count < limit else { break }
                chosen.append((candidate.id, candidate.date))
            }
        }
        return chosen.map(\.id)
    }

    // MARK: - Scoring

    private func score(cg: CGImage, isFavorite: Bool, category: TravelCategory?) async -> Double? {
        // Aesthetics + utility (screenshots/receipts) filter.
        var aesthetics = 0.0
        if let obs = try? await CalculateImageAestheticsScoresRequest().perform(on: cg) {
            if obs.isUtility { return nil }
            aesthetics = Double(obs.overallScore)
        }

        // Scene / content classification.
        let labels = classify(cg)
        let peoplePenalty = labelScore(labels, Self.peopleLabels) + labelScore(labels, Self.petLabels)
        let match = category.map { labelScore(labels, Self.labels(for: $0)) } ?? 0

        var total = aesthetics + 0.6 * Double(match) - 0.9 * Double(peoplePenalty)
        if isFavorite { total += 0.3 }
        return total
    }

    /// Best photo among the candidates that actually shows a mountain, or nil if none do.
    func mountainPhoto(candidateIDs: [String]) async -> String? {
        guard !candidateIDs.isEmpty else { return nil }
        var best: (id: String, score: Double)?
        for asset in fetchAssets(candidateIDs) {
            guard let cg = await thumbnail(for: asset)?.cgImage else { continue }
            let labels = classify(cg)
            let mountainScore = labelScore(labels, Self.mountainLabels)
            guard mountainScore >= 0.25 else { continue }   // must convincingly be a mountain
            var aesthetics = 0.0
            if let obs = try? await CalculateImageAestheticsScoresRequest().perform(on: cg) {
                if obs.isUtility { continue }
                aesthetics = Double(obs.overallScore)
            }
            let total = aesthetics + Double(mountainScore)
            if best == nil || total > best!.score { best = (asset.localIdentifier, total) }
        }
        return best?.id
    }

    private func classify(_ cg: CGImage) -> [String: Float] {
        var labels: [String: Float] = [:]
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        let request = VNClassifyImageRequest()
        try? handler.perform([request])
        for obs in (request.results ?? []) where obs.confidence > 0.1 {
            labels[obs.identifier.lowercased()] = obs.confidence
        }
        return labels
    }

    private func labelScore(_ labels: [String: Float], _ keys: Set<String>) -> Float {
        var total: Float = 0
        for (identifier, confidence) in labels where keys.contains(where: { identifier.contains($0) }) {
            total += confidence
        }
        return total
    }

    // MARK: - Photo loading

    private func fetchAssets(_ ids: [String]) -> [PHAsset] {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    private func thumbnail(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat   // single callback
            options.isNetworkAccessAllowed = false
            options.isSynchronous = false
            options.resizeMode = .fast
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 512, height: 512),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    // MARK: - Label vocabularies (VNClassifyImageRequest taxonomy)

    private static let peopleLabels: Set<String> = ["people", "person", "portrait", "selfie", "crowd", "baby", "wedding", "group"]
    private static let petLabels: Set<String> = ["dog", "cat", "pet", "puppy", "kitten"]
    private static let mountainLabels: Set<String> = ["mountain", "peak", "summit", "alp", "glacier", "cliff", "ridge", "hill", "valley", "snow", "mountaineering"]

    private static func labels(for category: TravelCategory) -> Set<String> {
        switch category {
        case .nature:    return ["nature", "outdoor", "landscape", "plant", "tree", "flower", "field", "forest", "grass", "park", "garden", "sky", "cloud", "lake", "river", "waterfall", "foliage", "meadow"]
        case .coastal:   return ["beach", "ocean", "sea", "coast", "shore", "wave", "water", "sand", "island", "harbor", "port", "pier", "sunset"]
        case .mountain:  return ["mountain", "hill", "valley", "snow", "glacier", "peak", "cliff", "alp", "summit", "rock", "hiking"]
        case .urban:     return ["building", "skyscraper", "city", "street", "urban", "downtown", "architecture", "skyline", "bridge", "tower", "road"]
        case .culture:   return ["architecture", "monument", "church", "temple", "cathedral", "castle", "palace", "ruins", "statue", "museum", "art", "historic", "structure"]
        case .adventure: return ["mountain", "desert", "cliff", "canyon", "trail", "hiking", "outdoor", "forest", "cave", "rock"]
        case .transit:   return []   // aesthetics only
        }
    }
}
