import Foundation

/// Pure transformation: [GeoPhoto] → TravelStats.
/// No side effects, fully testable, runs synchronously on whatever actor calls it.
struct StatisticsEngine: Sendable {
    /// - Parameters:
    ///   - homeCountryCode: excluded from trip detection so home life isn't counted as trips.
    ///   - manualTrips: trips the user entered by hand (no photos) — their countries and
    ///     places are merged into the country/continent stats, and dated ones are synthesized
    ///     into `Trip` rows so they appear alongside photo trips.
    ///   - excludedPhotoIDs: individual photos the user has excluded — dropped entirely
    ///     before any stats are computed. Reversible.
    func compute(from photos: [GeoPhoto],
                 homeCountryCode: String? = nil,
                 homeCoordinate: GeoPhoto.Coordinate? = nil,
                 manualTrips: [ManualTrip] = [],
                 excludedPhotoIDs: Set<String> = []) -> TravelStats {
        let geocoded = photos.filter {
            $0.isGeocoded && $0.country != nil && !excludedPhotoIDs.contains($0.id)
        }

        // --- Countries ---
        var countryMap: [String: CountryAccumulator] = [:]
        for photo in geocoded {
            guard let code = photo.countryCode, let name = photo.country else { continue }
            if countryMap[code] == nil {
                countryMap[code] = CountryAccumulator(code: code, name: name, flag: photo.flagEmoji)
            }
            countryMap[code]?.add(photo)
        }
        // --- Trips (continuous journeys away from home; may span countries) ---
        // Photo-detected trips, plus synthetic trips for the user's dated manual entries.
        let detectedTrips = TripDetector().detect(from: geocoded,
                                                  homeCoordinate: homeCoordinate,
                                                  homeCountryCode: homeCountryCode)
        let manualSynthTrips = manualTrips.compactMap(Self.synthesizeTrip)
        let trips = (detectedTrips + manualSynthTrips).sorted { $0.startDate < $1.startDate }

        // A country's trip count = number of trips (photo or manual) that included it.
        var tripCounts: [String: Int] = [:]
        for trip in trips {
            for code in Set(trip.countryCodes) { tripCounts[code, default: 0] += 1 }
        }

        var countries = countryMap.values
            .map { accumulator -> CountryStat in
                var stat = accumulator.build()
                stat.tripCount = max(1, tripCounts[stat.id] ?? 1)
                return stat
            }

        // Merge manual-trip countries: their places become cities, their dates extend the
        // visit range. Codes we already have from photos are augmented in place; new codes
        // are appended as photo-less countries so the counts stay accurate.
        let manualByCode = Self.aggregateManualCountries(manualTrips)
        for (code, agg) in manualByCode {
            if let idx = countries.firstIndex(where: { $0.id == code }) {
                var stat = countries[idx]
                let existingCityNames = Set(stat.cities.map(\.name))
                stat.cities.append(contentsOf: Self.cities(from: agg, code: code, existing: existingCityNames))
                if agg.firstVisit < stat.firstVisit { stat.firstVisit = agg.firstVisit }
                if agg.lastVisit > stat.lastVisit { stat.lastVisit = agg.lastVisit }
                stat.tripCount = max(stat.tripCount, tripCounts[code] ?? stat.tripCount)
                countries[idx] = stat
            } else {
                var stat = CountryStat(
                    id: code, name: agg.name, flag: agg.flag, photoCount: 0,
                    cities: Self.cities(from: agg, code: code, existing: []),
                    firstVisit: agg.firstVisit, lastVisit: agg.lastVisit, photoIDs: [],
                    representativeCoordinate: agg.coordinate
                )
                stat.tripCount = tripCounts[code] ?? 0
                countries.append(stat)
            }
        }

        countries.sort { $0.photoCount > $1.photoCount }

        // --- Cities ---
        var cityMap: [String: CityAccumulator] = [:]
        for photo in geocoded {
            guard let code = photo.countryCode,
                  let country = photo.country,
                  let city = photo.city else { continue }
            let key = "\(city),\(code)"
            if cityMap[key] == nil {
                cityMap[key] = CityAccumulator(id: key, name: city, country: country, code: code,
                                               coordinate: photo.coordinate)
            }
            cityMap[key]?.add(photo)
        }
        let allCities = cityMap.values
            .map { $0.build() }
            .sorted { $0.photoCount > $1.photoCount }

        // --- Monthly Timeline ---
        var monthBuckets: [String: (count: Int, countries: Set<String>)] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        for photo in geocoded {
            let key = formatter.string(from: photo.date)
            var bucket = monthBuckets[key] ?? (0, [])
            bucket.count += 1
            if let c = photo.country { bucket.countries.insert(c) }
            monthBuckets[key] = bucket
        }
        let timeline = monthBuckets
            .compactMap { key, value -> TimelineEntry? in
                guard let date = formatter.date(from: key) else { return nil }
                return TimelineEntry(id: UUID(), month: date, photoCount: value.count,
                                     countries: Array(value.countries))
            }
            .sorted { $0.month < $1.month }

        // --- Continents ---
        var continentMap: [Continent: [CountryStat]] = [:]
        for country in countries {
            guard let continent = ContinentMapper.continent(for: country.id) else { continue }
            continentMap[continent, default: []].append(country)
        }
        var continents: [ContinentStat] = Continent.visitable.map { continent in
            let cs = continentMap[continent] ?? []
            let photos = cs.reduce(0) { $0 + $1.photoCount }
            return ContinentStat(continent: continent, countries: cs, photoCount: photos)
        }
        // Antarctica is a bonus continent: only included when actually visited.
        if let antarcticaCountries = continentMap[.antarctica], !antarcticaCountries.isEmpty {
            let photos = antarcticaCountries.reduce(0) { $0 + $1.photoCount }
            continents.append(ContinentStat(continent: .antarctica,
                                            countries: antarcticaCountries,
                                            photoCount: photos))
        }

        // --- Wonders (location-based; works on all photos, even before geocoding) ---
        let wonders = WonderDetector().detect(photos: photos)

        return TravelStats(
            totalGeotaggedPhotos: geocoded.count,
            countries: countries,
            continents: continents,
            wonders: wonders,
            trips: trips,
            allCities: allCities,
            timelineEntries: timeline
        )
    }
}

// MARK: - Manual trips

private extension StatisticsEngine {
    /// Aggregated manual-trip data for a single country code.
    struct ManualCountryAgg {
        var name: String
        var flag: String
        var coordinate: GeoPhoto.Coordinate
        var places: [ManualTrip.Place] = []
        var firstVisit: Date = .distantPast
        var lastVisit: Date = .distantPast
    }

    /// Fold every manual trip's countries down to one entry per ISO code, collecting the
    /// places recorded and the widest date range across all trips that included the country.
    static func aggregateManualCountries(_ manualTrips: [ManualTrip]) -> [String: ManualCountryAgg] {
        var byCode: [String: ManualCountryAgg] = [:]
        for trip in manualTrips {
            for c in trip.countries {
                var agg = byCode[c.code] ?? ManualCountryAgg(
                    name: c.name, flag: c.flag,
                    coordinate: .init(latitude: c.latitude ?? c.places.first?.latitude ?? 0,
                                      longitude: c.longitude ?? c.places.first?.longitude ?? 0)
                )
                agg.places.append(contentsOf: c.places)
                if let start = trip.startDate {
                    agg.firstVisit = agg.firstVisit == .distantPast ? start : min(agg.firstVisit, start)
                }
                if let end = trip.endDate {
                    agg.lastVisit = max(agg.lastVisit, end)
                }
                byCode[c.code] = agg
            }
        }
        return byCode
    }

    /// Build `CityStat`s from a manual country's places, skipping any names already present.
    static func cities(from agg: ManualCountryAgg, code: String, existing: Set<String>) -> [CityStat] {
        var seen = existing
        var result: [CityStat] = []
        for place in agg.places where !seen.contains(place.name) {
            seen.insert(place.name)
            result.append(CityStat(
                id: "\(place.name),\(code)", name: place.name, country: agg.name, countryCode: code,
                photoCount: 0, firstVisit: agg.firstVisit, lastVisit: agg.lastVisit,
                representativeCoordinate: .init(latitude: place.latitude, longitude: place.longitude)
            ))
        }
        return result
    }

    /// Turn a dated manual trip into a real `Trip` so it appears in the Trips list. Undated
    /// entries (both dates nil) return nil — they only contribute to the country stats.
    static func synthesizeTrip(_ mt: ManualTrip) -> Trip? {
        guard let start = mt.startDate, let end = mt.endDate, !mt.countries.isEmpty else { return nil }

        let tripCountries = mt.countries.map {
            Trip.TripCountry(id: $0.code, name: $0.name, flag: $0.flag, photoCount: 0)
        }
        var stops: [Trip.TripStop] = []
        for c in mt.countries {
            for p in c.places {
                stops.append(Trip.TripStop(
                    id: "\(p.name),\(c.code)", name: p.name, countryCode: c.code, flag: c.flag,
                    latitude: p.latitude, longitude: p.longitude, firstVisit: start, photoCount: 0
                ))
            }
        }
        let primary = mt.countries[0]
        let coordinate: GeoPhoto.Coordinate
        if stops.isEmpty {
            coordinate = .init(latitude: primary.latitude ?? 0, longitude: primary.longitude ?? 0)
        } else {
            coordinate = .init(latitude: stops.map(\.latitude).reduce(0, +) / Double(stops.count),
                               longitude: stops.map(\.longitude).reduce(0, +) / Double(stops.count))
        }
        return Trip(
            id: "manual:\(mt.id)", countryCode: primary.code, country: primary.name, flag: primary.flag,
            countries: tripCountries, startDate: start, endDate: end, photoCount: 0,
            cities: stops.map(\.name), stops: stops, photoIDs: [],
            coordinate: coordinate, highestAltitude: nil, wonders: [], customName: mt.name
        )
    }
}

// MARK: - Private accumulators

private struct CountryAccumulator {
    let code: String
    let name: String
    let flag: String
    var photoCount = 0
    var photoIDs: [String] = []
    var cityMap: [String: CityAccumulator] = [:]
    var firstVisit = Date.distantFuture
    var lastVisit = Date.distantPast
    var representativeCoordinate = GeoPhoto.Coordinate(latitude: 0, longitude: 0)
    var minLat = Double.greatestFiniteMagnitude, maxLat = -Double.greatestFiniteMagnitude
    var minLon = Double.greatestFiniteMagnitude, maxLon = -Double.greatestFiniteMagnitude

    mutating func add(_ photo: GeoPhoto) {
        photoCount += 1
        photoIDs.append(photo.id)
        let coord = photo.coordinate
        minLat = min(minLat, coord.latitude);  maxLat = max(maxLat, coord.latitude)
        minLon = min(minLon, coord.longitude); maxLon = max(maxLon, coord.longitude)
        if photo.date < firstVisit { firstVisit = photo.date }
        if photo.date >= lastVisit {
            lastVisit = photo.date
            representativeCoordinate = photo.coordinate   // most recent photo's location
        }
        if let city = photo.city {
            let key = "\(city),\(code)"
            if cityMap[key] == nil {
                cityMap[key] = CityAccumulator(id: key, name: city, country: name, code: code,
                                               coordinate: photo.coordinate)
            }
            cityMap[key]?.add(photo)
        }
    }

    func build() -> CountryStat {
        CountryStat(
            id: code, name: name, flag: flag, photoCount: photoCount,
            cities: cityMap.values.map { $0.build() }.sorted { $0.photoCount > $1.photoCount },
            firstVisit: firstVisit, lastVisit: lastVisit, photoIDs: photoIDs,
            representativeCoordinate: representativeCoordinate,
            tripCount: 1,
            visitedBounds: photoCount > 0 && minLat <= maxLat
                ? GeoBounds(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
                : nil
        )
    }
}

private struct CityAccumulator {
    let id: String
    let name: String
    let country: String
    let code: String
    let coordinate: GeoPhoto.Coordinate
    var photoCount = 0
    var firstVisit = Date.distantFuture
    var lastVisit = Date.distantPast

    mutating func add(_ photo: GeoPhoto) {
        photoCount += 1
        if photo.date < firstVisit { firstVisit = photo.date }
        if photo.date > lastVisit { lastVisit = photo.date }
    }

    func build() -> CityStat {
        CityStat(id: id, name: name, country: country, countryCode: code,
                 photoCount: photoCount, firstVisit: firstVisit, lastVisit: lastVisit,
                 representativeCoordinate: coordinate)
    }
}
