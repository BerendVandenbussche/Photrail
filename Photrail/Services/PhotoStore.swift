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

    /// Write a completed geocode result onto its row.
    func applyGeocode(id: String, country: String?, countryCode: String?, city: String?) throws {
        var descriptor = FetchDescriptor<StoredPhoto>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let row = try modelContext.fetch(descriptor).first else { return }
        row.country = country
        row.countryCode = countryCode
        row.city = city
        row.isGeocoded = true
        try modelContext.save()
    }

    /// All stored photos as Sendable value types.
    func allPhotos() throws -> [GeoPhoto] {
        try modelContext.fetch(FetchDescriptor<StoredPhoto>()).map(\.geoPhoto)
    }

    /// Photos that still need reverse geocoding.
    func photosNeedingGeocoding() throws -> [GeoPhoto] {
        let descriptor = FetchDescriptor<StoredPhoto>(
            predicate: #Predicate { $0.isGeocoded == false }
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
