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
        // Candidates we couldn't judge at all (no thumbnail came back). Kept aside so a
        // library that Vision can't read still produces a full set rather than one photo.
        var unjudged: [(id: String, date: Date)] = []
        for asset in assets {
            let date = asset.creationDate ?? .distantPast
            guard let cg = await thumbnail(for: asset)?.cgImage else {
                unjudged.append((asset.localIdentifier, date))
                continue
            }
            // A nil score is a deliberate rejection (screenshot, receipt) — not a failure,
            // so those stay out of the backfill.
            guard let score = await score(cg: cg, isFavorite: asset.isFavorite, category: category) else { continue }
            scored.append((asset.localIdentifier, score, date))
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
        // Last resort: fill the remaining slots with candidates Vision never saw, still
        // honouring the spacing rule so the result doesn't collapse onto one afternoon.
        if chosen.count < limit {
            for candidate in unjudged {
                guard chosen.count < limit else { break }
                if chosen.allSatisfy({ abs($0.date.timeIntervalSince(candidate.date)) >= minSpacing }) {
                    chosen.append(candidate)
                }
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

    /// What a photo should depict for `bestPhoto(_:subject:)`.
    enum Subject {
        case mountain, landmark, nature, coastal
        /// Distinctly-shaped monuments — Christ the Redeemer, the Moai, the Statue of Liberty.
        /// Worth its own case because `.landmark` matches on "building" and "architecture",
        /// which a statue doesn't score on and a nearby rooftop does.
        case statue
        case tower
        case bridge

        /// What a photo of a given wonder should actually show.
        ///
        /// Deliberately separate from `TravelPersonalityEngine.wonderKind(forID:)`, which
        /// answers a different question — what a *visit* says about the traveller — and puts the
        /// Statue of Liberty under "coastal" because it's on the water. True, and exactly wrong
        /// for picking a photo of it: it makes a shot of the harbour beat a shot of the statue.
        static func forWonder(id: String) -> Subject {
            switch id {
            case "christ-redeemer", "statue-liberty", "moai":               return .statue
            case "eiffel-tower", "big-ben", "burj-khalifa", "leaning-tower": return .tower
            case "golden-gate":                                             return .bridge
            case "machu-picchu", "mount-fuji":                              return .mountain
            case "grand-canyon", "niagara-falls":                           return .nature
            case "santorini":                                               return .coastal
            default:                                                        return .landmark
            }
        }
    }

    /// Labels that mean "this photo is of something else entirely" — the wildlife, the lunch,
    /// the pet — regardless of which monument we were looking for.
    ///
    /// This is the fix for the Christ the Redeemer problem: the monkeys on the roof score on
    /// "building" and used to sail through unopposed.
    ///
    /// Every entry has to survive a *substring* match (see `labelScore`), which rules out short
    /// words that hide inside real ones — "cat" would flag every cathedral.
    private static let offSubjectLabels: Set<String> = [
        "animal", "primate", "monkey", "wildlife", "bird", "insect", "pet", "rodent", "reptile",
        "food", "meal", "dessert", "beverage", "drink"
    ]

    /// Best photo among the candidates that actually depicts `subject`, or nil if none do.
    /// Used to surface a real photo of a mountain peak or a wonder/landmark — not a nearby selfie.
    /// - Parameter allowFallback: when nothing clears `minMatch`, return the *least wrong*
    ///   candidate rather than nil. Vision's taxonomy is coarse and a monument can easily fail to
    ///   score on any of our labels, and the caller's alternative is usually "newest photo taken
    ///   nearby" — which is how the monkeys on the roof at Christ the Redeemer kept winning.
    ///   Ranking by "least off-subject" still buries the wildlife and the lunch.
    func bestPhoto(candidateIDs: [String], subject: Subject,
                   minMatch: Float = 0.25, allowFallback: Bool = false) async -> String? {
        guard !candidateIDs.isEmpty else { return nil }
        let keys = Self.labels(for: subject)
        let avoid = Self.avoidLabels(for: subject)
        var best: (id: String, score: Double)?
        var fallback: (id: String, score: Double)?
        for asset in fetchAssets(candidateIDs) {
            guard let cg = await thumbnail(for: asset)?.cgImage else { continue }
            let labels = classify(cg)
            let match = labelScore(labels, keys)
            // Penalize photos dominated by the wrong scenery (e.g. a mountain panorama
            // when we want the statue/monument that happens to sit on a mountain).
            let off = labelScore(labels, avoid)
            var aesthetics = 0.0
            if let obs = try? await CalculateImageAestheticsScoresRequest().perform(on: cg) {
                if obs.isUtility { continue }
                aesthetics = Double(obs.overallScore)
            }
            let total = aesthetics + Double(match) - 1.3 * Double(off)
            guard match >= minMatch else {            // didn't convincingly show the subject
                if allowFallback, fallback == nil || total > fallback!.score {
                    fallback = (asset.localIdentifier, total)
                }
                continue
            }
            if best == nil || total > best!.score { best = (asset.localIdentifier, total) }
        }
        return best?.id ?? fallback?.id
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
            // `.fastFormat` — also a single callback, but it settles for whatever is cached
            // on device. `.highQualityFormat` returns *nil* for an asset whose full image
            // lives only in iCloud, which with "Optimize iPhone Storage" is most of a real
            // library — every one of those candidates was being dropped before it was ever
            // scored. Downloading instead would mean fetching 120 originals to pick six.
            options.deliveryMode = .fastFormat
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
    private static func labels(for subject: Subject) -> Set<String> {
        switch subject {
        case .mountain: return ["mountain", "peak", "summit", "alp", "glacier", "cliff", "ridge", "hill", "valley", "snow", "mountaineering"]
        case .landmark: return ["architecture", "monument", "building", "temple", "church", "cathedral", "castle", "palace", "ruins", "statue", "tower", "structure", "landmark", "pyramid", "historic", "arch", "skyscraper", "bridge", "fountain"]
        case .nature:   return ["nature", "landscape", "mountain", "valley", "canyon", "waterfall", "forest", "desert", "cliff", "rock", "lake", "river", "outdoor"]
        case .coastal:  return ["beach", "ocean", "sea", "coast", "water", "island", "sunset", "harbor", "bay", "cliff"]
        case .statue:   return ["statue", "sculpture", "monument", "memorial", "carving", "figurine", "landmark"]
        case .tower:    return ["tower", "skyscraper", "spire", "steeple", "clock", "architecture", "structure", "landmark", "building"]
        case .bridge:   return ["bridge", "suspension", "viaduct", "architecture", "structure", "landmark"]
        }
    }

    /// Labels that should count *against* a photo for a given subject (wrong scenery).
    private static func avoidLabels(for subject: Subject) -> Set<String> {
        // Wildlife and lunch count against *every* subject — see `offSubjectLabels`.
        switch subject {
        case .landmark: return offSubjectLabels.union(["mountain", "valley", "landscape", "snow", "beach", "ocean", "sea", "hill", "field", "forest", "sky"])
        case .mountain: return offSubjectLabels.union(["building", "architecture", "indoor", "room", "interior", "office"])
        case .nature:   return offSubjectLabels.union(["building", "architecture", "indoor", "room", "interior", "street"])
        case .coastal:  return offSubjectLabels.union(["mountain", "indoor", "building", "room", "interior"])
        // Not "sky": a statue on a hilltop is almost always shot against it.
        case .statue:   return offSubjectLabels.union(["beach", "ocean", "sea", "forest", "interior", "room", "street", "vehicle"])
        case .tower:    return offSubjectLabels.union(["beach", "ocean", "forest", "mountain", "interior", "room"])
        case .bridge:   return offSubjectLabels.union(["forest", "mountain", "interior", "room"])
        }
    }

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
