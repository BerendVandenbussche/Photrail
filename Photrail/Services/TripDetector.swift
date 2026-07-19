import Foundation
import CoreLocation

/// Groups photos into trips. A trip is a continuous journey away from home that may
/// span several countries. Walking photos in time order, a trip ends when:
///  - a photo is taken back in the home town (you're home), or
///  - the next photo is unlikely to belong to the same journey. Rather than a flat
///    time cutoff, each candidate is scored by a *same‑trip probability* (see
///    `sameTripProbability`) that weighs the distance, the time gap, whether the two
///    places share a continent, and whether home sits between them (a natural round
///    trip). A low score starts a new trip — so a Prague weekend and a Canada holiday
///    a few days apart no longer merge, while a European road trip still stays whole.
struct TripDetector: Sendable {

    /// - Parameters:
    ///   - maxGapDays: the reference gap for scoring; larger gaps steadily lower the
    ///     same‑trip probability.
    ///   - hardMaxGapDays: an absolute cap — beyond this two photos never merge, even
    ///     within one country (so two separate visits months apart don't become one trip).
    ///   - directTravelDays: a move within this many days is treated as active travel and
    ///     always continues the trip, however far (a direct long‑haul flight leg counts).
    ///   - sameTripThreshold: the minimum probability [0,1] to keep the same trip.
    ///   - homeCoordinate / homeRadiusKm: a photo within this radius of home ends the trip.
    ///   - homeCountryCode: fallback home boundary when no home coordinate is known.
    func detect(from photos: [GeoPhoto],
                maxGapDays: Int = 7,
                hardMaxGapDays: Int = 30,
                directTravelDays: Double = 1.5,
                sameTripThreshold: Double = 0.5,
                homeCoordinate: GeoPhoto.Coordinate? = nil,
                homeCountryCode: String? = nil,
                homeRadiusKm: Double = 50) -> [Trip] {
        let relevant = photos
            .filter { $0.isGeocoded && $0.countryCode != nil }
            .sorted { $0.date < $1.date }
        guard !relevant.isEmpty else { return [] }

        let homeLocation = homeCoordinate?.clLocation

        func isHome(_ photo: GeoPhoto) -> Bool {
            if let homeLocation {
                return photo.coordinate.clLocation.distance(from: homeLocation) <= homeRadiusKm * 1000
            }
            if let homeCountryCode { return photo.countryCode == homeCountryCode }
            return false
        }

        var trips: [Trip] = []
        var current: [GeoPhoto] = []

        for photo in relevant {
            // Back home → the current journey is over.
            if isHome(photo) {
                if !current.isEmpty { trips.append(makeTrip(current)); current = [] }
                continue
            }
            guard let last = current.last else { current = [photo]; continue }

            let gapDays = photo.date.timeIntervalSince(last.date) / 86_400
            let sameTrip = gapDays <= Double(hardMaxGapDays) &&
                sameTripProbability(from: last, to: photo, gapDays: gapDays,
                                    home: homeLocation, maxGapDays: maxGapDays,
                                    directTravelDays: directTravelDays) >= sameTripThreshold
            if sameTrip {
                current.append(photo)                                  // still the same journey
            } else {
                trips.append(makeTrip(current)); current = [photo]     // new journey
            }
        }
        if !current.isEmpty { trips.append(makeTrip(current)) }

        return trips.sorted { $0.startDate > $1.startDate }
    }

    /// Probability [0,1] that `next` belongs to the same trip as `last`, given the gap
    /// between them. Higher means "keep the journey going". Purely heuristic.
    ///
    /// The intuition: two photos are the same trip when it's physically natural to have
    /// travelled straight from one to the other without breaking the journey. A short gap
    /// means you were actively travelling (any distance is fine). Beyond that, nearby,
    /// same‑continent places score high; far, cross‑continent jumps score low — and if
    /// *home* sits roughly on the line between them, a trip home in the gap is likely, so
    /// they're probably two separate trips.
    func sameTripProbability(from last: GeoPhoto, to next: GeoPhoto,
                             gapDays: Double,
                             home: CLLocation?,
                             maxGapDays: Int = 7,
                             directTravelDays: Double = 1.5) -> Double {
        // Actively travelling: a same‑/next‑day move is one continuous journey, however far.
        if gapDays <= directTravelDays { return 1 }

        // A longer stay within the *same* country is still one trip.
        if last.countryCode == next.countryCode { return 0.9 }

        // Country changed after a multi‑day gap — judge how plausible one journey is.
        let distanceKm = last.coordinate.clLocation.distance(from: next.coordinate.clLocation) / 1000

        // Nearer hops are far likelier to be the same trip.
        let distanceScore: Double
        switch distanceKm {
        case ..<800:   distanceScore = 0.85
        case ..<1500:  distanceScore = 0.65
        case ..<3000:  distanceScore = 0.40
        case ..<6000:  distanceScore = 0.18
        default:       distanceScore = 0.06
        }

        // Same continent keeps the journey plausible; crossing continents rarely does.
        let sameContinent: Bool = {
            guard let a = last.countryCode.flatMap(ContinentMapper.continent(for:)),
                  let b = next.countryCode.flatMap(ContinentMapper.continent(for:)) else { return false }
            return a == b
        }()
        let continentFactor = sameContinent ? 1.0 : 0.45

        // The longer the gap, the more time there was to break the journey (e.g. go home).
        let gapFactor = max(0.4, 1 - 0.5 * min(1, gapDays / Double(maxGapDays)))

        var score = distanceScore * continentFactor * gapFactor

        // If home sits roughly *between* the two places, going home in the gap barely
        // lengthens the path — a strong hint these are two trips (Prague → home → Canada).
        if let home {
            let lastFromHome = last.coordinate.clLocation.distance(from: home) / 1000
            let nextFromHome = next.coordinate.clLocation.distance(from: home) / 1000
            if lastFromHome > 100, nextFromHome > 100, distanceKm > 1,
               lastFromHome + nextFromHome <= distanceKm * 1.35 {
                score *= 0.4
            }
        }
        return score
    }

    private func makeTrip(_ photos: [GeoPhoto]) -> Trip {
        let first = photos.first!

        // Countries on the trip, ordered by first appearance; primary = most photographed.
        var countryPhotos: [String: [GeoPhoto]] = [:]
        var countryOrder: [String] = []
        for photo in photos {
            guard let code = photo.countryCode else { continue }
            if countryPhotos[code] == nil { countryOrder.append(code) }
            countryPhotos[code, default: []].append(photo)
        }
        let countries: [Trip.TripCountry] = countryOrder.map { code in
            let ps = countryPhotos[code]!
            return Trip.TripCountry(id: code,
                                    name: ps.first?.country ?? code,
                                    flag: ps.first?.flagEmoji ?? "🌍",
                                    photoCount: ps.count)
        }
        let primary = countries.max { $0.photoCount < $1.photoCount } ?? countries.first!

        // Cities → located stops (keyed by city + country, since names repeat across borders).
        var byCity: [String: [GeoPhoto]] = [:]
        for photo in photos {
            guard let city = photo.city, let code = photo.countryCode else { continue }
            byCity["\(city),\(code)", default: []].append(photo)
        }
        let cities = byCity.sorted { $0.value.count > $1.value.count }
            .compactMap { $0.value.first?.city }
        let stops = byCity.map { key, cityPhotos -> Trip.TripStop in
            let count = Double(cityPhotos.count)
            let clat = cityPhotos.map(\.coordinate.latitude).reduce(0, +) / count
            let clon = cityPhotos.map(\.coordinate.longitude).reduce(0, +) / count
            let firstVisit = cityPhotos.map(\.date).min() ?? first.date
            let sample = cityPhotos.first!
            return Trip.TripStop(id: key, name: sample.city ?? key,
                                 countryCode: sample.countryCode ?? "",
                                 flag: sample.flagEmoji,
                                 latitude: clat, longitude: clon,
                                 firstVisit: firstVisit, photoCount: cityPhotos.count)
        }
        .sorted { $0.firstVisit < $1.firstVisit }

        // Centroid
        let lat = photos.map(\.coordinate.latitude).reduce(0, +) / Double(photos.count)
        let lon = photos.map(\.coordinate.longitude).reduce(0, +) / Double(photos.count)

        let start = photos.map(\.date).min() ?? first.date
        let end = photos.map(\.date).max() ?? first.date

        // Stable id keyed on the start *day*. Trips are sequential and non-overlapping,
        // so the start day identifies a trip uniquely — and, unlike a country+timestamp
        // key, it doesn't drift when photo counts change or the primary country flips,
        // so per-trip data (notes, cover) stays attached.
        let d = Calendar.current.dateComponents([.year, .month, .day], from: start)
        let id = String(format: "trip-%04d-%02d-%02d", d.year ?? 0, d.month ?? 0, d.day ?? 0)

        let highestAltitude = photos.compactMap(\.altitude).max()

        let wonders = WonderDetector().detect(photos: photos)
            .filter { $0.photoCount > 0 }
            .map { Trip.WonderHit(id: $0.wonder.id, name: $0.wonder.name,
                                  emoji: $0.wonder.emoji,
                                  isOfficial: $0.wonder.category == .sevenWonders,
                                  photoID: $0.representativePhotoID) }

        return Trip(
            id: id,
            countryCode: primary.code,
            country: primary.name,
            flag: primary.flag,
            countries: countries,
            startDate: start,
            endDate: end,
            photoCount: photos.count,
            cities: cities,
            stops: stops,
            photoIDs: photos.map(\.id),
            coordinate: .init(latitude: lat, longitude: lon),
            highestAltitude: highestAltitude,
            wonders: wonders,
            customName: TripNameStore.name(for: id)
        )
    }
}
