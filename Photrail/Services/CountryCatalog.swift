import Foundation

/// The full list of countries the app knows, for manual country entry.
enum CountryCatalog {
    struct Option: Identifiable, Sendable {
        let code: String
        let name: String
        let flag: String
        var id: String { code }
    }

    /// All known countries, alphabetically by localized name.
    static let all: [Option] = ContinentMapper.allCodes
        .map { Option(code: $0, name: name(for: $0), flag: flag(for: $0)) }
        .sorted { $0.name < $1.name }

    /// Localized country name for an ISO code (falls back to the code).
    static func name(for code: String) -> String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }

    /// Flag emoji from an ISO 3166-1 alpha-2 code.
    static func flag(for code: String) -> String {
        code.uppercased().unicodeScalars
            .compactMap { Unicode.Scalar(127397 + $0.value) }
            .map { String($0) }
            .joined()
    }
}
