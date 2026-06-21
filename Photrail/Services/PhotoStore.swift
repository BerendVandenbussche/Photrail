import Foundation
import SwiftData

/// Serialized access to the SwiftData store from any actor/background task.
/// `@ModelActor` synthesizes `init(modelContainer:)` and provides an isolated
/// `modelContext`, so all reads/writes happen on this actor's executor.
@ModelActor
actor PhotoStore {

    /// Insert any photos not already stored, preserving existing geocoding.
    /// Returns the number of newly-inserted rows.
    @discardableResult
    func insertNewPhotos(_ photos: [GeoPhoto]) throws -> Int {
        let existing = try modelContext.fetch(FetchDescriptor<StoredPhoto>())
        let existingIDs = Set(existing.map(\.id))

        var inserted = 0
        for photo in photos where !existingIDs.contains(photo.id) {
            modelContext.insert(StoredPhoto(
                id: photo.id,
                latitude: photo.coordinate.latitude,
                longitude: photo.coordinate.longitude,
                date: photo.date
            ))
            inserted += 1
        }
        if inserted > 0 { try modelContext.save() }
        return inserted
    }

    /// Apply offline country results to many rows in a single save.
    func applyCountries(_ results: [(id: String, country: String?, countryCode: String?)]) throws {
        guard !results.isEmpty else { return }
        let byID = Dictionary(results.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let ids = Set(byID.keys)
        let descriptor = FetchDescriptor<StoredPhoto>(predicate: #Predicate { ids.contains($0.id) })
        for row in try modelContext.fetch(descriptor) {
            guard let r = byID[row.id] else { continue }
            row.country = r.country
            row.countryCode = r.countryCode
            row.isGeocoded = true
        }
        try modelContext.save()
    }

    /// Write a city result onto its row (marks the city lookup as done either way).
    func applyCity(id: String, city: String?) throws {
        var descriptor = FetchDescriptor<StoredPhoto>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let row = try modelContext.fetch(descriptor).first else { return }
        row.city = city
        row.cityChecked = true
        try modelContext.save()
    }

    /// All stored photos as Sendable value types.
    func allPhotos() throws -> [GeoPhoto] {
        try modelContext.fetch(FetchDescriptor<StoredPhoto>()).map(\.geoPhoto)
    }

    /// Photos that still need offline country resolution, oldest first.
    /// Ascending date order matters for new-country detection: historical photos are
    /// processed before today's, so a country visited earlier seeds the "seen" set first.
    func photosNeedingCountry() throws -> [GeoPhoto] {
        let descriptor = FetchDescriptor<StoredPhoto>(
            predicate: #Predicate { $0.isGeocoded == false },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return try modelContext.fetch(descriptor).map(\.geoPhoto)
    }

    /// Photos with a resolved country that still need a city lookup, oldest first.
    func photosNeedingCity() throws -> [GeoPhoto] {
        let descriptor = FetchDescriptor<StoredPhoto>(
            predicate: #Predicate { $0.isGeocoded == true && $0.countryCode != nil && $0.cityChecked == false },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return try modelContext.fetch(descriptor).map(\.geoPhoto)
    }

    func totalCount() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<StoredPhoto>())
    }

    func deleteAll() throws {
        try modelContext.delete(model: StoredPhoto.self)
        try modelContext.save()
    }
}
