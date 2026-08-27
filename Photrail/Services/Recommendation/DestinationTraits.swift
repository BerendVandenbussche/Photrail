import Foundation

/// The one thing about a destination that cannot be derived from the bundled data.
///
/// Coastal-ness comes from `OfflineCoastline`, urban-vs-wild from `OfflinePlaces`, and culture
/// from the wonders a country holds — all measured, all honest. Altitude has no dataset here:
/// `TravelPersonalityEngine` reads it from each photo's EXIF, which a candidate obviously has
/// none of. Without this list the "mountain" axis would be dead for every country, and a
/// profile dominated by Mountain Seeker could only ever be offered mountain *wonders*.
///
/// So: an authored set, kept deliberately small and uncontroversial — countries where high
/// mountains are a headline reason people go, not merely countries that contain some.
enum DestinationTraits {
    static let mountainous: Set<String> = [
        "AD", "AF", "AL", "AM", "AR", "AT", "AZ", "BA", "BO", "BT",
        "CH", "CL", "CO", "EC", "GE", "IS", "KG", "LI", "ME", "MK",
        "NO", "NP", "NZ", "PE", "PK", "RO", "SI", "SK", "TJ",
    ]

    /// Weight added to `.mountain` (and a little to `.adventure`) for those countries. Sized to
    /// sit alongside the measured signals rather than swamp them — comparable to the engine's
    /// own `altitudeHigh` weight for a single photo.
    static let mountainWeight = 1.1
}
