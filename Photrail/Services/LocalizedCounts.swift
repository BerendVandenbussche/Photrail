import Foundation

/// Localized, plural-aware count phrases. The underlying keys carry plural
/// variations in Localizable.xcstrings, so both English and Dutch stay grammatical
/// ("1 dag" vs "2 dagen"). Use these instead of building count strings by hand.
enum L {
    static func days(_ n: Int) -> String { String(localized: "\(n) days") }
    static func daysAway(_ n: Int) -> String { String(localized: "\(n) days away") }
    static func countries(_ n: Int) -> String { String(localized: "\(n) countries") }
    static func cities(_ n: Int) -> String { String(localized: "\(n) cities") }
    static func trips(_ n: Int) -> String { String(localized: "\(n) trips") }
    static func photos(_ n: Int) -> String { String(localized: "\(n) photos") }
    static func yearsAgo(_ n: Int) -> String { String(localized: "\(n) years ago") }
}
