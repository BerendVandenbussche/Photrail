import Foundation

/// Turns scored candidates into an ordered shortlist. Pure, synchronous and free of I/O, so
/// the part of this feature that actually decides where you should go is the part that is
/// easiest to test — see `DestinationRankerTests`.
enum DestinationRanker {

    /// How many entries the card cycles through. Small on purpose: it is also the list the
    /// on-device model chooses from, and a long list is a long prompt with worse choices in it.
    static let shortlistSize = 5

    /// Order the pool by how well it fits this traveller.
    ///
    /// - Parameters:
    ///   - candidates: the pool, each with the style vector built by `DestinationCandidateBuilder`
    ///   - profile: the user's personality, whose percentages are the other half of the match
    ///   - homeDistanceKm: great-circle distance from home per candidate id; empty when no home
    ///     is set, in which case reach is not considered at all
    static func rank(_ candidates: [DestinationCandidateBuilder.Scored],
                     profile: TravelPersonalityProfile,
                     homeDistanceKm: [String: Double]) -> [RankedDestination] {
        let percentages = profile.categoryPercentages
        guard percentages.values.reduce(0, +) > 0 else { return [] }

        // How far this traveller actually goes, 0.3…1. Someone whose profile is a third transit
        // and adventure has demonstrably crossed oceans; someone doing city breaks within a
        // train ride has not, and telling them to fly to Easter Island is a worse suggestion
        // than a good one nearby, however well it matches on style.
        let reachSignal = (percentages[.transit] ?? 0) + (percentages[.adventure] ?? 0)
        let reach = 0.3 + 0.7 * min(1, reachSignal / 35)

        return candidates.map { scored in
            let match = cosineSimilarity(scored.vector, percentages)
            var score = match

            if let distance = homeDistanceKm[scored.candidate.id] {
                // At most a 30% haircut, at the far side of the planet, for the least
                // far-reaching traveller. Never enough to beat a genuinely better match.
                let far = min(1, distance / 20_000)
                score *= 1 - 0.3 * far * (1 - reach)
            }

            // Wonders edge out countries at equal fit: they are curated, they are a single
            // concrete thing to go and stand in front of, and photographing one later ticks
            // off the Wonders section the app already has.
            if scored.candidate.isWonder { score *= 1.05 }

            return RankedDestination(candidate: scored.candidate, match: match, score: score)
        }
        .sorted { $0.score > $1.score }
    }

    /// The top entries, at most one per country.
    ///
    /// Without the cap a shortlist reads as one destination repeated — "Machu Picchu", "Peru",
    /// "Cusco" are the same holiday, and the model would be choosing between synonyms. The
    /// higher-scoring entry wins the slot, which after the wonder bonus is usually the wonder.
    static func shortlist(from ranked: [RankedDestination],
                          limit: Int = shortlistSize) -> [RankedDestination] {
        var seenCountries = Set<String>()
        var result: [RankedDestination] = []
        for entry in ranked where seenCountries.insert(entry.candidate.countryCode).inserted {
            result.append(entry)
            if result.count == limit { break }
        }
        return result
    }

    /// Cosine similarity between a candidate's weights and the profile's percentages, 0…1.
    ///
    /// Both sides are non-negative, so this can't go below zero. It is deliberately the raw
    /// cosine and not a stretched-out version of it: the same number is shown to the user as a
    /// match percentage, and inflating the spread to make the card look decisive would be
    /// making up precision the underlying signals don't have.
    static func cosineSimilarity(_ vector: TravelCategoryScores,
                                 _ percentages: [TravelCategory: Double]) -> Double {
        var dot = 0.0, vectorNorm = 0.0, profileNorm = 0.0
        for category in TravelCategory.allCases {
            let a = vector[category]
            let b = percentages[category] ?? 0
            dot += a * b
            vectorNorm += a * a
            profileNorm += b * b
        }
        guard vectorNorm > 0, profileNorm > 0 else { return 0 }
        return dot / (vectorNorm.squareRoot() * profileNorm.squareRoot())
    }
}
