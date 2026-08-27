import XCTest
@testable import Photrail

/// Covers the half of "Where next?" that actually decides where you should go. The pitch
/// writers are prose; this is the recommendation.
final class DestinationRankerTests: XCTestCase {

    // MARK: - Fixtures

    private func candidate(_ id: String,
                           kind: DestinationKind,
                           country: String = "XX") -> DestinationCandidate {
        DestinationCandidate(kind: kind, name: id, countryCode: country, emoji: "📍",
                             latitude: 0, longitude: 0, highlights: [])
    }

    private func scored(_ id: String,
                        _ weights: [TravelCategory: Double],
                        kind: DestinationKind? = nil,
                        country: String = "XX") -> DestinationCandidateBuilder.Scored {
        DestinationCandidateBuilder.Scored(
            candidate: candidate(id, kind: kind ?? .country(code: country), country: country),
            vector: TravelCategoryScores(weights))
    }

    private func profile(_ weights: [TravelCategory: Double]) -> TravelPersonalityProfile {
        let total = weights.values.reduce(0, +)
        let slices = weights
            .map { TravelPersonalityProfile.Slice(category: $0.key, percentage: $0.value / total * 100) }
            .sorted { $0.percentage > $1.percentage }
        return TravelPersonalityProfile(slices: slices, photoCount: 500, confidence: 1)
    }

    // MARK: - Matching

    func testMountainProfilePrefersMountainCandidate() {
        let candidates = [
            scored("alps", [.mountain: 1, .adventure: 0.4], country: "AT"),
            scored("beach", [.coastal: 1], country: "PT"),
            scored("city", [.urban: 1], country: "PL"),
        ]
        let ranked = DestinationRanker.rank(candidates,
                                            profile: profile([.mountain: 60, .adventure: 25, .nature: 15]),
                                            homeDistanceKm: [:])
        XCTAssertEqual(ranked.first?.candidate.name, "alps")
        XCTAssertGreaterThan(ranked[0].match, ranked[1].match)
    }

    func testCoastalProfilePrefersCoastalCandidate() {
        let candidates = [
            scored("alps", [.mountain: 1], country: "AT"),
            scored("beach", [.coastal: 1], country: "PT"),
        ]
        let ranked = DestinationRanker.rank(candidates,
                                            profile: profile([.coastal: 70, .urban: 30]),
                                            homeDistanceKm: [:])
        XCTAssertEqual(ranked.first?.candidate.name, "beach")
    }

    func testMatchIsZeroWhenNothingOverlaps() {
        let ranked = DestinationRanker.rank([scored("beach", [.coastal: 1])],
                                            profile: profile([.mountain: 100]),
                                            homeDistanceKm: [:])
        XCTAssertEqual(ranked.first?.match ?? -1, 0, accuracy: 0.0001)
    }

    func testEmptyProfileProducesNoRanking() {
        let empty = TravelPersonalityProfile(slices: [], photoCount: 0, confidence: 0)
        XCTAssertTrue(DestinationRanker.rank([scored("beach", [.coastal: 1])],
                                             profile: empty,
                                             homeDistanceKm: [:]).isEmpty)
    }

    // MARK: - Reach

    func testDistancePenaltyDemotesFarCandidateForAHomebody() {
        let near = scored("near", [.urban: 1], country: "FR")
        let far = scored("far", [.urban: 1], country: "JP")
        let homebody = profile([.urban: 90, .culture: 10])   // no transit, no adventure
        let ranked = DestinationRanker.rank([near, far], profile: homebody,
                                            homeDistanceKm: [near.candidate.id: 300,
                                                             far.candidate.id: 18_000])
        XCTAssertEqual(ranked.first?.candidate.name, "near")
        // Same style, so the ordering is the reach adjustment alone.
        XCTAssertEqual(ranked[0].match, ranked[1].match, accuracy: 0.0001)
    }

    func testFarReachingProfileIsBarelyPenalised() {
        let near = scored("near", [.urban: 1], country: "FR")
        let far = scored("far", [.urban: 1], country: "JP")
        let distances = [near.candidate.id: 300.0, far.candidate.id: 18_000.0]
        let wanderer = profile([.urban: 50, .transit: 30, .adventure: 20])
        let homebody = profile([.urban: 90, .culture: 10])

        func gap(_ p: TravelPersonalityProfile) -> Double {
            let ranked = DestinationRanker.rank([near, far], profile: p, homeDistanceKm: distances)
            let byName = Dictionary(uniqueKeysWithValues: ranked.map { ($0.candidate.name, $0.score) })
            return byName["near"]! - byName["far"]!
        }
        XCTAssertLessThan(gap(wanderer), gap(homebody))
    }

    func testNoHomeMeansNoDistanceAdjustment() {
        let near = scored("near", [.urban: 1], country: "FR")
        let far = scored("far", [.urban: 1], country: "JP")
        let ranked = DestinationRanker.rank([near, far],
                                            profile: profile([.urban: 100]),
                                            homeDistanceKm: [:])
        XCTAssertEqual(ranked[0].score, ranked[1].score, accuracy: 0.0001)
    }

    func testWonderOutranksAnEquallyMatchedCountry() {
        let wonder = scored("wonder", [.culture: 1], kind: .wonder(id: "w"), country: "IT")
        let country = scored("country", [.culture: 1], country: "ES")
        let ranked = DestinationRanker.rank([country, wonder],
                                            profile: profile([.culture: 100]),
                                            homeDistanceKm: [:])
        XCTAssertEqual(ranked.first?.candidate.name, "wonder")
    }

    // MARK: - Shortlist

    func testShortlistKeepsOnlyOneEntryPerCountry() {
        let ranked = DestinationRanker.rank([
            scored("machu-picchu", [.mountain: 1], kind: .wonder(id: "machu-picchu"), country: "PE"),
            scored("peru", [.mountain: 0.9], country: "PE"),
            scored("nepal", [.mountain: 0.8], country: "NP"),
        ], profile: profile([.mountain: 100]), homeDistanceKm: [:])

        let shortlist = DestinationRanker.shortlist(from: ranked)
        XCTAssertEqual(shortlist.map(\.candidate.countryCode), ["PE", "NP"])
        XCTAssertEqual(shortlist.first?.candidate.name, "machu-picchu")
    }

    func testShortlistRespectsItsLimit() {
        let ranked = DestinationRanker.rank((0..<20).map {
            scored("c\($0)", [.urban: 1], country: "C\($0)")
        }, profile: profile([.urban: 100]), homeDistanceKm: [:])
        XCTAssertEqual(DestinationRanker.shortlist(from: ranked).count,
                       DestinationRanker.shortlistSize)
    }

    // MARK: - Site vectors

    func testRemotePointScoresAsNatureAndCoastalPointAsCoastal() {
        let remote = DestinationCandidateBuilder.siteVector(wonderKind: nil,
                                                            coastalDistanceKm: 900,
                                                            cityDistanceKm: 120)
        XCTAssertGreaterThan(remote[.nature], remote[.urban])
        XCTAssertEqual(remote[.coastal], 0)

        let seaside = DestinationCandidateBuilder.siteVector(wonderKind: nil,
                                                             coastalDistanceKm: 3,
                                                             cityDistanceKm: 2)
        XCTAssertGreaterThan(seaside[.coastal], 0)
        XCTAssertGreaterThan(seaside[.urban], 0)
    }

    func testSiteVectorIsNeverEmpty() {
        let nothing = DestinationCandidateBuilder.siteVector(wonderKind: nil,
                                                             coastalDistanceKm: nil,
                                                             cityDistanceKm: nil)
        XCTAssertGreaterThan(nothing.total, 0)
    }

    // MARK: - Template pitch

    func testTemplatePitchNamesTheDestinationAndPicksTheFirstEntry() async {
        let entry = RankedDestination(
            candidate: DestinationCandidate(kind: .country(code: "NP"), name: "Nepal",
                                            countryCode: "NP", emoji: "🇳🇵",
                                            latitude: 28, longitude: 84,
                                            highlights: ["Kathmandu", "Pokhara"]),
            match: 0.9, score: 0.9)
        let context = TripSuggestionContext(dominant: .mountain,
                                            topCategories: [CategoryShare(category: .mountain, percentage: 60)],
                                            recentCountryNames: ["Italy"],
                                            seenWonderNames: ["Mount Fuji"],
                                            countryCount: 12,
                                            languageIdentifier: "en")

        let pitch = await TemplatePitchWriter().pitch(shortlist: [entry], context: context)
        XCTAssertEqual(pitch.index, 0)
        XCTAssertFalse(pitch.generatedByModel)
        XCTAssertTrue(pitch.text.contains("Nepal"))
        XCTAssertTrue(pitch.text.contains("Kathmandu"))
    }

    func testTemplatePitchSurvivesAnEmptyShortlist() async {
        let context = TripSuggestionContext(dominant: nil, topCategories: [],
                                            recentCountryNames: [], seenWonderNames: [],
                                            countryCount: 0, languageIdentifier: "en")
        let pitch = await TemplatePitchWriter().pitch(shortlist: [], context: context)
        XCTAssertTrue(pitch.text.isEmpty)
        XCTAssertFalse(pitch.generatedByModel)
    }
}
