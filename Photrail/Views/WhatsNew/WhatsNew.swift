import SwiftUI

/// A one-time "New in Photrail" announcement, shown by `WhatsNewView`.
///
/// To announce something in a new release: replace `WhatsNew.current` with a new announcement
/// and give it a new `id`. Everyone sees it once. Set `current` to `nil` to show nothing.
struct WhatsNewAnnouncement: Identifiable, Sendable {
    /// Stored once the sheet has been shown. A new id shows it again to everyone.
    let id: String
    let eyebrow: LocalizedStringResource
    let title: LocalizedStringResource
    let rows: [Row]
    /// The main button, if any. Hidden when its action has nothing to act on.
    let action: Action?

    struct Row: Identifiable, Sendable {
        var id: String { symbol }
        let symbol: String
        let color: Color
        let title: LocalizedStringResource
        let detail: LocalizedStringResource
        /// Shown to users without Lifetime instead of `detail`, e.g. to mention a free trial.
        var freeDetail: LocalizedStringResource? = nil

        func detail(hasLifetime: Bool) -> LocalizedStringResource {
            hasLifetime ? detail : (freeDetail ?? detail)
        }
    }

    struct Action: Sendable {
        let title: LocalizedStringResource
        let symbol: String
        let kind: Kind

        /// What the button does. Add a case for each new kind of destination.
        enum Kind: Sendable {
            /// Open the latest finished trip with its film preview open.
            case filmOfLatestTrip
        }
    }
}

enum WhatsNew {
    /// The announcement for this release, or `nil` for none.
    static let current: WhatsNewAnnouncement? = friends

    /// 5.5: sharing. Many users never found the films and share cards behind the toolbar icon.
    static let sharing = WhatsNewAnnouncement(
        id: "sharing-1",
        eyebrow: "New in Photrail",
        title: "Share your travels",
        rows: [
            .init(symbol: "film.fill", color: .pink,
                  title: "Trip films",
                  detail: "Turn any trip into a short video, with maps, photos and stats.",
                  freeDetail: "Turn any trip into a short video, with maps, photos and stats. Your first one is free."),
            .init(symbol: "photo.on.rectangle.angled", color: .blue,
                  title: "Share cards",
                  detail: "Share a trip, your year, your calendar or a memory as an image. Use the share button at the top."),
            .init(symbol: "calendar", color: .orange,
                  title: "Year in Travel",
                  detail: "A film of your whole year."),
        ],
        action: .init(title: "Make a film of my last trip", symbol: "play.fill", kind: .filmOfLatestTrip)
    )

    /// 5.13: everything since 5.9 (build 28): friends, daily postcards, country info, flight
    /// hints, Spotlight and the new animations.
    static let friends = WhatsNewAnnouncement(
        id: "friends-1",
        eyebrow: "New in Photrail",
        title: "Friends, flights and more",
        rows: [
            .init(symbol: "person.2.fill", color: .green,
                  title: "Friends",
                  detail: "See where you rank among your Game Center friends, right on the Dashboard."),
            .init(symbol: "envelope.fill", color: .teal,
                  title: "Daily postcards",
                  detail: "On travel days, an evening postcard of the day's photos, ready to share."),
            .init(symbol: "powerplug.fill", color: .blue,
                  title: "Before you go",
                  detail: "Plugs, languages, currency, time difference and driving side for each country of a planned trip, compared with home."),
            .init(symbol: "airplane", color: .orange,
                  title: "Flight suggestions",
                  detail: "Photrail suggests the flights of past trips from photos taken at airports."),
            .init(symbol: "magnifyingglass", color: .purple,
                  title: "Find trips in Spotlight",
                  detail: "Search for a year or a month, like “June 2025”, to find your trips."),
            .init(symbol: "sparkles", color: .pink,
                  title: "Smoother all round",
                  detail: "Photos zoom open, maps fly to each stop and your numbers count up."),
        ],
        action: nil
    )
}
