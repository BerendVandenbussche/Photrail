import Foundation

/// Static catalog of world wonders and famous landmarks with match radii.
/// Radii are deliberately generous for large sites so a photo taken anywhere
/// on/around the landmark still counts.
enum WonderCatalog {
    static let all: [Wonder] = [
        // New 7 Wonders of the World
        Wonder(id: "great-wall", name: "Great Wall of China", countryCode: "CN", emoji: "🧱",
               category: .sevenWonders, latitude: 40.4319, longitude: 116.5704, radiusMeters: 30_000),
        Wonder(id: "petra", name: "Petra", countryCode: "JO", emoji: "🏛️",
               category: .sevenWonders, latitude: 30.3285, longitude: 35.4444, radiusMeters: 2_000),
        Wonder(id: "christ-redeemer", name: "Christ the Redeemer", countryCode: "BR", emoji: "✝️",
               category: .sevenWonders, latitude: -22.9519, longitude: -43.2105, radiusMeters: 800),
        Wonder(id: "machu-picchu", name: "Machu Picchu", countryCode: "PE", emoji: "🏔️",
               category: .sevenWonders, latitude: -13.1631, longitude: -72.5450, radiusMeters: 1_500),
        Wonder(id: "chichen-itza", name: "Chichén Itzá", countryCode: "MX", emoji: "🛕",
               category: .sevenWonders, latitude: 20.6843, longitude: -88.5678, radiusMeters: 1_000),
        Wonder(id: "colosseum", name: "Colosseum", countryCode: "IT", emoji: "🏛️",
               category: .sevenWonders, latitude: 41.8902, longitude: 12.4922, radiusMeters: 500),
        Wonder(id: "taj-mahal", name: "Taj Mahal", countryCode: "IN", emoji: "🕌",
               category: .sevenWonders, latitude: 27.1751, longitude: 78.0421, radiusMeters: 800),

        // Ancient / classic landmarks
        Wonder(id: "giza-pyramids", name: "Pyramids of Giza", countryCode: "EG", emoji: "🔺",
               category: .landmark, latitude: 29.9792, longitude: 31.1342, radiusMeters: 2_500),
        Wonder(id: "acropolis", name: "Acropolis of Athens", countryCode: "GR", emoji: "🏛️",
               category: .landmark, latitude: 37.9715, longitude: 23.7257, radiusMeters: 600),
        Wonder(id: "stonehenge", name: "Stonehenge", countryCode: "GB", emoji: "🪨",
               category: .landmark, latitude: 51.1789, longitude: -1.8262, radiusMeters: 600),
        Wonder(id: "angkor-wat", name: "Angkor Wat", countryCode: "KH", emoji: "🛕",
               category: .landmark, latitude: 13.4125, longitude: 103.8670, radiusMeters: 3_000),
        Wonder(id: "moai", name: "Easter Island Moai", countryCode: "CL", emoji: "🗿",
               category: .landmark, latitude: -27.1212, longitude: -109.3666, radiusMeters: 15_000),

        // Modern landmarks
        Wonder(id: "eiffel-tower", name: "Eiffel Tower", countryCode: "FR", emoji: "🗼",
               category: .landmark, latitude: 48.8584, longitude: 2.2945, radiusMeters: 600),
        Wonder(id: "statue-liberty", name: "Statue of Liberty", countryCode: "US", emoji: "🗽",
               category: .landmark, latitude: 40.6892, longitude: -74.0445, radiusMeters: 600),
        Wonder(id: "sagrada-familia", name: "Sagrada Família", countryCode: "ES", emoji: "⛪️",
               category: .landmark, latitude: 41.4036, longitude: 2.1744, radiusMeters: 400),
        Wonder(id: "big-ben", name: "Big Ben", countryCode: "GB", emoji: "🕰️",
               category: .landmark, latitude: 51.5007, longitude: -0.1246, radiusMeters: 400),
        Wonder(id: "sydney-opera", name: "Sydney Opera House", countryCode: "AU", emoji: "🎭",
               category: .landmark, latitude: -33.8568, longitude: 151.2153, radiusMeters: 600),
        Wonder(id: "burj-khalifa", name: "Burj Khalifa", countryCode: "AE", emoji: "🏙️",
               category: .landmark, latitude: 25.1972, longitude: 55.2744, radiusMeters: 600),
        Wonder(id: "golden-gate", name: "Golden Gate Bridge", countryCode: "US", emoji: "🌉",
               category: .landmark, latitude: 37.8199, longitude: -122.4783, radiusMeters: 2_500),
        Wonder(id: "leaning-tower", name: "Leaning Tower of Pisa", countryCode: "IT", emoji: "🏛️",
               category: .landmark, latitude: 43.7230, longitude: 10.3966, radiusMeters: 300),
        Wonder(id: "brandenburg-gate", name: "Brandenburg Gate", countryCode: "DE", emoji: "🏛️",
               category: .landmark, latitude: 52.5163, longitude: 13.3777, radiusMeters: 300),
        Wonder(id: "neuschwanstein", name: "Neuschwanstein Castle", countryCode: "DE", emoji: "🏰",
               category: .landmark, latitude: 47.5576, longitude: 10.7498, radiusMeters: 1_000),

        // Natural wonders
        Wonder(id: "grand-canyon", name: "Grand Canyon", countryCode: "US", emoji: "🏜️",
               category: .landmark, latitude: 36.0544, longitude: -112.1401, radiusMeters: 20_000),
        Wonder(id: "niagara-falls", name: "Niagara Falls", countryCode: "US", emoji: "💦",
               category: .landmark, latitude: 43.0962, longitude: -79.0377, radiusMeters: 2_000),
        Wonder(id: "mount-fuji", name: "Mount Fuji", countryCode: "JP", emoji: "🗻",
               category: .landmark, latitude: 35.3606, longitude: 138.7274, radiusMeters: 8_000),
        Wonder(id: "santorini", name: "Santorini", countryCode: "GR", emoji: "🏝️",
               category: .landmark, latitude: 36.4618, longitude: 25.3753, radiusMeters: 4_000),
    ]
}
