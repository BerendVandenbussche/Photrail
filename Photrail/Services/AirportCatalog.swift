import Foundation
import CoreLocation

/// Coordinates of major international airports. A photo taken at one is treated as *transit*
/// and excluded from trip grouping, so a layover (e.g. a Frankfurt stopover en route to
/// Brazil) doesn't add that country to the trip ("Germany + Brazil" for a Brazil holiday).
///
/// Deliberately not exhaustive — it covers the international connecting hubs where layovers
/// realistically happen, not every regional airstrip. Excluded photos still count toward
/// overall country/city statistics; they're only kept out of the per-trip country list.
enum AirportCatalog {

    /// A photo within this many km of a hub is considered "at the airport".
    static let radiusKm: Double = 4

    /// `(latitude, longitude)` of each hub, grouped loosely by region.
    static let hubs: [(lat: Double, lon: Double)] = [
        // --- Europe ---
        (50.037, 8.562),    // Frankfurt FRA
        (48.354, 11.786),   // Munich MUC
        (51.470, -0.454),   // London Heathrow LHR
        (51.148, -0.190),   // London Gatwick LGW
        (49.010, 2.548),    // Paris Charles de Gaulle CDG
        (52.310, 4.768),    // Amsterdam Schiphol AMS
        (50.901, 4.484),    // Brussels BRU
        (41.275, 28.752),   // Istanbul IST
        (40.977, 28.821),   // Istanbul Sabiha SAW
        (40.472, -3.561),   // Madrid MAD
        (41.297, 2.078),    // Barcelona BCN
        (41.800, 12.239),   // Rome Fiumicino FCO
        (45.630, 8.723),    // Milan Malpensa MXP
        (47.464, 8.549),    // Zurich ZRH
        (48.110, 16.570),   // Vienna VIE
        (55.618, 12.656),   // Copenhagen CPH
        (59.652, 17.918),   // Stockholm Arlanda ARN
        (60.194, 11.100),   // Oslo OSL
        (60.317, 24.963),   // Helsinki HEL
        (38.774, -9.134),   // Lisbon LIS
        (53.421, -6.270),   // Dublin DUB
        (52.166, 20.967),   // Warsaw WAW
        (50.049, 14.260),   // Prague PRG
        (55.973, 37.415),   // Moscow Sheremetyevo SVO
        (53.630, 9.988),    // Hamburg HAM
        (51.289, 6.767),    // Dusseldorf DUS
        (52.362, 13.501),   // Berlin BER
        (45.740, 16.069),   // Zagreb ZAG
        (37.937, 23.945),   // Athens ATH

        // --- Middle East & Africa ---
        (25.253, 55.364),   // Dubai DXB
        (24.433, 54.651),   // Abu Dhabi AUH
        (25.273, 51.608),   // Doha DOH
        (24.958, 46.699),   // Riyadh RUH
        (30.122, 31.406),   // Cairo CAI
        (9.020, 38.799),    // Addis Ababa ADD
        (-1.319, 36.928),   // Nairobi NBO
        (-26.139, 28.246),  // Johannesburg JNB
        (-33.970, 18.602),  // Cape Town CPT
        (33.367, -7.590),   // Casablanca CMN
        (6.577, 3.321),     // Lagos LOS

        // --- Asia ---
        (28.556, 77.100),   // Delhi DEL
        (19.089, 72.868),   // Mumbai BOM
        (13.690, 100.750),  // Bangkok Suvarnabhumi BKK
        (2.744, 101.710),   // Kuala Lumpur KUL
        (1.359, 103.989),   // Singapore SIN
        (-6.126, 106.656),  // Jakarta CGK
        (14.509, 121.020),  // Manila MNL
        (22.308, 113.918),  // Hong Kong HKG
        (31.144, 121.805),  // Shanghai Pudong PVG
        (40.080, 116.585),  // Beijing Capital PEK
        (23.392, 113.299),  // Guangzhou CAN
        (25.078, 121.233),  // Taipei Taoyuan TPE
        (37.469, 126.451),  // Seoul Incheon ICN
        (35.765, 140.386),  // Tokyo Narita NRT
        (35.549, 139.780),  // Tokyo Haneda HND
        (34.435, 135.244),  // Osaka Kansai KIX

        // --- North America ---
        (43.677, -79.630),  // Toronto Pearson YYZ
        (45.470, -73.741),  // Montreal YUL
        (49.194, -123.184), // Vancouver YVR
        (40.640, -73.779),  // New York JFK
        (40.690, -74.177),  // Newark EWR
        (41.978, -87.908),  // Chicago O'Hare ORD
        (33.641, -84.427),  // Atlanta ATL
        (33.943, -118.408), // Los Angeles LAX
        (37.622, -122.379), // San Francisco SFO
        (25.795, -80.287),  // Miami MIA
        (32.897, -97.038),  // Dallas Fort Worth DFW
        (29.984, -95.341),  // Houston IAH
        (36.084, -115.154), // Las Vegas LAS
        (47.449, -122.309), // Seattle SEA
        (19.436, -99.072),  // Mexico City MEX
        (8.974, -79.383),   // Panama City PTY

        // --- South America ---
        (-23.431, -46.473), // São Paulo Guarulhos GRU
        (-22.809, -43.251), // Rio de Janeiro GIG
        (-34.822, -58.536), // Buenos Aires Ezeiza EZE
        (-33.393, -70.786), // Santiago SCL
        (4.702, -74.147),   // Bogotá BOG
        (-12.022, -77.107), // Lima LIM

        // --- Oceania ---
        (-33.940, 151.175), // Sydney SYD
        (-37.669, 144.841), // Melbourne MEL
        (-27.386, 153.118), // Brisbane BNE
        (-36.999, 174.792), // Auckland AKL
    ]

    /// Whether a coordinate falls within `radiusKm` of any known hub.
    static func isAtAirport(_ coordinate: GeoPhoto.Coordinate) -> Bool {
        let location = coordinate.clLocation
        for hub in hubs
        where location.distance(from: CLLocation(latitude: hub.lat, longitude: hub.lon)) <= radiusKm * 1000 {
            return true
        }
        return false
    }
}
