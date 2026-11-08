import Foundation

/// Someone else's countries, received through a compare link.
struct ComparePayload: Equatable, Identifiable, Sendable {
    /// Their first name, when they gave one.
    var name: String?
    /// Their profile emoji.
    var emoji: String
    var countryCodes: Set<String>

    var id: String { "\(emoji)|\(name ?? "")|\(countryCodes.sorted().joined())" }
}

/// The link behind the compare QR code:
/// `https://photrail.berendvandenbussche.be/compare/#v=1&e=🦊&n=Berend&c=BEFRDE…`
///
/// Everything lives in the fragment, which browsers never send to the server: without the
/// app installed the website shows a download page, and still never sees anyone's countries.
/// No backend, no account — the link *is* the data.
enum CompareLink {
    static let host = "photrail.berendvandenbussche.be"
    /// With the trailing slash: the web server redirects `/compare` to `/compare/` (via
    /// plain http) before serving the page. Links without it still parse.
    static let path = "/compare/"
    static let version = "1"

    /// Limits for input that comes from outside the app.
    static let maxCountries = 300
    static let maxNameLength = 30

    /// RFC 3986 unreserved characters: the only ones left unencoded in a value.
    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    static func url(for payload: ComparePayload) -> URL {
        var items: [(String, String)] = [("v", version), ("e", cleanEmoji(payload.emoji))]
        if let name = cleanName(payload.name) { items.append(("n", name)) }
        // Two letters per country, no separators: compact enough for a QR code even for
        // someone who has been everywhere.
        items.append(("c", payload.countryCodes.map { $0.uppercased() }.sorted().joined()))
        // Encoded by hand with a strict set: `URLComponents` leaves `&`, `=` and `+` alone in
        // query values, and a name containing one would break the link.
        let fragment = items
            .map { "\($0.0)=\($0.1.addingPercentEncoding(withAllowedCharacters: unreserved) ?? "")" }
            .joined(separator: "&")

        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.percentEncodedFragment = fragment
        // Only fails for a malformed host or path, which are constants.
        return components.url ?? URL(string: "https://\(host)\(path)")!
    }

    /// The payload in a compare link, or nil when `url` isn't one (or holds nothing usable).
    static func parse(_ url: URL) -> ComparePayload? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host?.lowercased() == host,
              components.path.hasPrefix("/compare"),
              let fragment = components.percentEncodedFragment
        else { return nil }
        return parse(fragment: fragment)
    }

    /// The fragment alone: `v=1&e=…&n=…&c=…`.
    static func parse(fragment: String) -> ComparePayload? {
        var query = URLComponents()
        query.percentEncodedQuery = fragment
        guard let items = query.queryItems else { return nil }
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

        guard value("v") == version, let raw = value("c") else { return nil }

        let known = Set(ContinentMapper.allCodes)
        var codes = Set<String>()
        var index = raw.startIndex
        while index < raw.endIndex, codes.count < maxCountries {
            let end = raw.index(index, offsetBy: 2, limitedBy: raw.endIndex) ?? raw.endIndex
            let code = raw[index..<end].uppercased()
            if known.contains(code) { codes.insert(code) }   // ignore anything we don't know
            index = end
        }
        guard !codes.isEmpty else { return nil }

        return ComparePayload(name: cleanName(value("n")),
                              emoji: cleanEmoji(value("e")),
                              countryCodes: codes)
    }

    /// Trimmed and capped; nil when empty.
    static func cleanName(_ name: String?) -> String? {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxNameLength))
    }

    /// One character (grapheme), so a link can't fill the header with text.
    static func cleanEmoji(_ emoji: String?) -> String {
        guard let first = emoji?.trimmingCharacters(in: .whitespacesAndNewlines).first else { return "🧳" }
        return String(first)
    }
}
