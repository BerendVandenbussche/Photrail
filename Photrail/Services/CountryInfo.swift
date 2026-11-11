import Foundation

/// Practical facts about a country for travellers: plugs, voltage, driving side, calling code
/// and main languages, from the bundled `countryinfo.tsv` (about 5 KB, offline). The currency
/// comes from iOS itself, and the names of languages and currencies are localised by iOS too.
struct CountryInfo: Equatable, Sendable {
    let countryCode: String
    /// Plug types, IEC letters: ["A", "C"].
    let plugs: [String]
    /// "220", or "127/220" where it varies by region.
    let voltage: String
    /// "60", or "50/60".
    let frequency: String
    let drivesOnLeft: Bool
    /// "51", or "1-268" for the NANP islands.
    let callingCode: String
    /// Main languages, most useful first, as ISO 639 codes.
    let languages: [String]

    var volts: [Int] { voltage.split(separator: "/").compactMap { Int($0) } }
    var callingCodeText: String { "+" + callingCode.replacingOccurrences(of: "-", with: " ") }
    var plugText: String { plugs.joined(separator: ", ") }
    var powerText: String { "\(voltage) V · \(frequency) Hz" }

    /// The country's currency (ISO 4217), as iOS knows it.
    var currencyCode: String? { Self.currencyCode(for: countryCode) }

    static func currencyCode(for region: String) -> String? {
        Locale(identifier: "und_\(region.uppercased())").currency?.identifier
    }

    func languageNames(locale: Locale = .current) -> [String] {
        languages.compactMap { code in
            locale.localizedString(forLanguageCode: code).map { name in
                name.prefix(1).uppercased(with: locale) + name.dropFirst()
            }
        }
    }

    func currencyName(locale: Locale = .current) -> String? {
        guard let code = currencyCode else { return nil }
        let name = locale.localizedString(forCurrencyCode: code) ?? code
        return "\(name) (\(code))"
    }
}

enum CountryInfoDirectory {
    /// Loaded on first use, one row per country.
    static let all: [String: CountryInfo] = load()

    static func info(for countryCode: String) -> CountryInfo? { all[countryCode.uppercased()] }

    static func parse(_ text: String) -> [String: CountryInfo] {
        var result: [String: CountryInfo] = [:]
        for line in text.split(separator: "\n") where !line.hasPrefix("#") {
            let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard f.count == 7 else { continue }
            result[f[0]] = CountryInfo(countryCode: f[0],
                                       plugs: f[1].split(separator: ",").map(String.init),
                                       voltage: f[2], frequency: f[3], drivesOnLeft: f[4] == "L",
                                       callingCode: f[5],
                                       languages: f[6].split(separator: ",").map(String.init))
        }
        return result
    }

    private static func load() -> [String: CountryInfo] {
        guard let url = Bundle.main.url(forResource: "countryinfo", withExtension: "tsv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        return parse(text)
    }
}

/// A destination's facts held against the user's home country: do the plugs fit, is the
/// voltage different, what's the time difference. Without a home country only the facts.
struct CountryTips: Equatable {
    enum PlugAdvice: Equatable {
        /// Every kind of plug from home fits.
        case fits
        /// Some fit, others need an adapter (Belgium → Peru: C fits, E doesn't).
        case partly(fitting: [String], needAdapter: [String])
        /// None fit.
        case adapter
    }

    enum VoltageAdvice: Equatable {
        case same
        /// 100–127 V where home has 220–240 V: chargers usually cope, hair dryers don't.
        case lower
        /// The other way round.
        case higher
    }

    enum TimeDifference: Equatable {
        case same
        /// Hours ahead of home (negative: behind); a range for countries with several zones.
        case hours(min: Double, max: Double)
    }

    let info: CountryInfo
    let plugAdvice: PlugAdvice?
    /// The destination's socket types that a plug from home goes into; nil without a home.
    let socketsForHomePlugs: Set<String>?
    /// The home country and its plug types, when known.
    let homeCountryCode: String?
    let homePlugs: [String]

    /// Whether a plug from home of this type goes into one of the destination's sockets.
    func homePlugFits(_ type: String) -> Bool {
        !Self.socketsFitting[type, default: [type]].isDisjoint(with: info.plugs)
    }
    let voltageAdvice: VoltageAdvice
    let sameCurrency: Bool?
    let sameDrivingSide: Bool?
    let timeDifference: TimeDifference?

    var countryCode: String { info.countryCode }

    /// - Parameters:
    ///   - date: when the user is there, so summer time is counted right.
    ///   - homeZone: the zone at home (the home country's, near the home location).
    static func make(destination: String, home: String?, on date: Date,
                     homeZone: TimeZone?) -> CountryTips? {
        guard let info = CountryInfoDirectory.info(for: destination) else { return nil }
        let homeInfo = home.flatMap(CountryInfoDirectory.info(for:))

        var plugAdvice: PlugAdvice?
        var sockets: Set<String>?
        var voltage = VoltageAdvice.same
        if let homeInfo {
            plugAdvice = Self.plugAdvice(home: homeInfo.plugs, destination: info.plugs)
            sockets = Set(info.plugs.filter { socket in
                homeInfo.plugs.contains { socketsFitting[$0, default: [$0]].contains(socket) }
            })
            voltage = Self.voltageAdvice(home: homeInfo.volts, destination: info.volts)
        }

        var time: TimeDifference?
        let zones = TripTimeZone.zones(countryCode: destination)
        if let homeZone, !zones.isEmpty {
            let base = homeZone.secondsFromGMT(for: date)
            let offsets = zones.map { Double($0.secondsFromGMT(for: date) - base) / 3600 }
            let low = offsets.min() ?? 0, high = offsets.max() ?? 0
            time = low == 0 && high == 0 ? .same : .hours(min: low, max: high)
        }

        return CountryTips(info: info, plugAdvice: plugAdvice, socketsForHomePlugs: sockets,
                           homeCountryCode: homeInfo?.countryCode, homePlugs: homeInfo?.plugs ?? [],
                           voltageAdvice: voltage,
                           sameCurrency: homeInfo.map { $0.currencyCode == info.currencyCode },
                           sameDrivingSide: homeInfo.map { $0.drivesOnLeft == info.drivesOnLeft },
                           timeDifference: time)
    }

    /// Which sockets each plug goes into. A Europlug (C) fits most European-style sockets,
    /// and E and F plugs today are nearly all the hybrid that fits both.
    static let socketsFitting: [String: Set<String>] = [
        "A": ["A", "B"],
        "C": ["C", "E", "F", "H", "J", "K", "L", "N"],
        "E": ["E", "F"],
        "F": ["E", "F"],
    ]

    static func plugAdvice(home: [String], destination: [String]) -> PlugAdvice {
        let sockets = Set(destination)
        let fitting = home.filter { !socketsFitting[$0, default: [$0]].isDisjoint(with: sockets) }
        if fitting.count == home.count { return .fits }
        if fitting.isEmpty { return .adapter }
        return .partly(fitting: fitting, needAdapter: home.filter { !fitting.contains($0) })
    }

    static func voltageAdvice(home: [Int], destination: [Int]) -> VoltageAdvice {
        guard let homeLow = home.min(), let homeHigh = home.max(),
              let low = destination.min(), let high = destination.max() else { return .same }
        if high <= 130 && homeLow >= 200 { return .lower }
        if low >= 200 && homeHigh <= 130 { return .higher }
        return .same
    }
}
