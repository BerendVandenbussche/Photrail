import Foundation

/// Pure transformation: [GeoPhoto] → TravelStats.
/// No side effects, fully testable, runs synchronously on whatever actor calls it.
struct StatisticsEngine: Sendable {
    func compute(from photos: [GeoPhoto]) -> TravelStats {
        let geocoded = photos.filter { $0.isGeocoded && $0.country != nil }

        // --- Countries ---
        var countryMap: [String: CountryAccumulator] = [:]
        for photo in geocoded {
            guard let code = photo.countryCode, let name = photo.country else { continue }
            if countryMap[code] == nil {
                countryMap[code] = CountryAccumulator(code: code, name: name, flag: photo.flagEmoji)
            }
            countryMap[code]?.add(photo)
        }
        let countries = countryMap.values
            .map { $0.build() }
            .sorted { $0.photoCount > $1.photoCount }

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
            allCities: allCities,
            timelineEntries: timeline
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

    mutating func add(_ photo: GeoPhoto) {
        photoCount += 1
        photoIDs.append(photo.id)
        if photo.date < firstVisit { firstVisit = photo.date }
        if photo.date > lastVisit { lastVisit = photo.date }
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
            firstVisit: firstVisit, lastVisit: lastVisit, photoIDs: photoIDs
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
