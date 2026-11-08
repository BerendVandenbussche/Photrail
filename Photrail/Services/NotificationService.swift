import Foundation
import UserNotifications

/// Where tapping a notification should land.
///
/// Carried in the request's `userInfo` and read back by `NotificationDelegate`, which hands it
/// to `IntentRouter` — the same bridge Spotlight and Siri go through, so all three routes share
/// one implementation in `MainTabView`.
enum NotificationRoute {
    case trip(id: String)
    case yearRecap
    case map
    /// A planned trip that hasn't started yet, by `PlannedTrip.id`.
    case plannedTrip(id: String)
    /// The photo trip taken between these days — the "welcome back" reminder. Carries the
    /// dates rather than the plan's id because the plan is retired once its trip is found.
    case tripDuring(start: Date, end: Date)
    /// The daily postcard of this day.
    case postcard(day: Date)

    private static let kind = "route"
    private static let tripID = "tripID"
    private static let planID = "planID"
    private static let start = "start"
    private static let end = "end"

    var userInfo: [String: String] {
        switch self {
        case .trip(let id):        return [Self.kind: "trip", Self.tripID: id]
        case .yearRecap:           return [Self.kind: "yearRecap"]
        case .map:                 return [Self.kind: "map"]
        case .plannedTrip(let id): return [Self.kind: "plannedTrip", Self.planID: id]
        case .tripDuring(let start, let end):
            return [Self.kind: "tripDuring",
                    Self.start: String(start.timeIntervalSince1970),
                    Self.end: String(end.timeIntervalSince1970)]
        case .postcard(let day):
            return [Self.kind: "postcard", Self.start: String(day.timeIntervalSince1970)]
        }
    }

    init?(userInfo: [AnyHashable: Any]) {
        switch userInfo[Self.kind] as? String {
        case "trip":
            guard let id = userInfo[Self.tripID] as? String else { return nil }
            self = .trip(id: id)
        case "yearRecap": self = .yearRecap
        case "map":       self = .map
        case "plannedTrip":
            guard let id = userInfo[Self.planID] as? String else { return nil }
            self = .plannedTrip(id: id)
        case "tripDuring":
            guard let start = (userInfo[Self.start] as? String).flatMap(TimeInterval.init),
                  let end = (userInfo[Self.end] as? String).flatMap(TimeInterval.init) else { return nil }
            self = .tripDuring(start: Date(timeIntervalSince1970: start), end: Date(timeIntervalSince1970: end))
        case "postcard":
            guard let day = (userInfo[Self.start] as? String).flatMap(TimeInterval.init) else { return nil }
            self = .postcard(day: Date(timeIntervalSince1970: day))
        default:          return nil
        }
    }
}

/// Local notifications for travel milestones (e.g. arriving in a new country).
enum NotificationService {

    /// Ask for notification permission. Safe to call repeatedly — iOS only prompts once.
    ///
    /// Shows the real system prompt, so only call this where the user has *asked* for nudges
    /// (the Profile toggle). Onboarding uses `requestProvisionalAuthorization()` instead.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Grant notifications quietly, with no prompt at all.
    ///
    /// `.provisional` authorizes immediately and silently: nudges land in Notification Center
    /// without a banner or sound, and the first one iOS delivers carries "Keep"/"Turn Off"
    /// buttons. The user judges a real "Welcome to Croatia!" rather than an abstract permission
    /// alert stacked behind the photo-library one, and a reflexive "Don't Allow" during
    /// onboarding can no longer silence the feature forever.
    ///
    /// Suits this app because the nudges are deliberately rare (7-day cap, once per thing) —
    /// quiet delivery is the price, and it's cheap at this volume. A user who wants banners can
    /// still flip the Profile toggle, which calls `requestAuthorization()` and upgrades.
    ///
    /// No-op once any decision exists: iOS ignores the request when the status isn't
    /// `.notDetermined`, so this never downgrades a user who already granted full alerts.
    static func requestProvisionalAuthorization() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge, .provisional])
    }

    /// Current permission state, so the UI can explain why nudges are silent.
    ///
    /// A single "Don't Allow" during onboarding leaves every notify path below returning early
    /// with no trace, which is indistinguishable from "nothing was worth notifying about".
    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Schedule a "new country" notification, delivered immediately.
    /// Uses the country code as the request identifier so duplicates coalesce.
    static func notifyNewCountry(code: String, name: String, flag: String) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "\(flag) Welcome to \(name)!")
        content.body = String(localized: "A new country for your map — enjoy your trip! ✈️")
        content.sound = .default
        // No trip exists yet (the country was just entered), so land on the map instead.
        content.userInfo = NotificationRoute.map.userInfo

        let request = UNNotificationRequest(
            identifier: "new-country-\(code)",
            content: content,
            trigger: nil   // deliver as soon as possible
        )
        try? await center.add(request)
    }

    /// Nudge that a recent trip is ready to relive/share. Delivered soon.
    static func notifyTripReady(tripID: String, flag: String, country: String) async {
        guard await isAuthorized() else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "\(flag) Your \(country) trip is ready")
        content.body = String(localized: "Relive your journey and share it ✈️")
        content.sound = .default
        content.userInfo = NotificationRoute.trip(id: tripID).userInfo
        let request = UNNotificationRequest(identifier: "trip-ready-\(tripID)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Schedule the "Year in Travel is ready" nudge for Jan 2 (7pm) — a calm day when
    /// people are back and reflecting, not lost in New Year's Eve. Delivered soon if
    /// that moment has already passed.
    static func scheduleYearRecap(year: Int) async {
        guard await isAuthorized() else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "✈️ Your \(year) Year in Travel is ready")
        content.body = String(localized: "See everywhere you went this year — and share your recap.")
        content.sound = .default
        content.userInfo = NotificationRoute.yearRecap.userInfo

        var comps = DateComponents()
        comps.year = year + 1; comps.month = 1; comps.day = 2; comps.hour = 19; comps.minute = 0
        let target = Calendar.current.date(from: comps) ?? Date()
        let trigger: UNNotificationTrigger? = target > Date()
            ? UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            : nil
        let request = UNNotificationRequest(identifier: "year-recap-\(year)", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Planned trips

    /// The three reminders a plan sends, at 19:00 local time: a week before, the evening
    /// before, and the day after it ends.
    private enum PlanReminder: String, CaseIterable {
        case week, eve, back

        func id(for planID: String) -> String { "planned-\(planID)-\(rawValue)" }

        func day(for plan: PlannedTrip, calendar: Calendar) -> Date? {
            switch self {
            case .week: return calendar.date(byAdding: .day, value: -7, to: plan.startDate)
            case .eve:  return calendar.date(byAdding: .day, value: -1, to: plan.startDate)
            case .back: return calendar.date(byAdding: .day, value: 1, to: plan.endDate)
            }
        }
    }

    /// (Re)schedule a plan's reminders. Always clears the old ones first, so an edit moves them
    /// and a disabled switch removes them. A reminder whose moment has passed is skipped, and
    /// so is the week-before one for a trip planned less than a week ahead (the evening-before
    /// reminder already covers it).
    static func schedulePlannedTrip(_ plan: PlannedTrip, enabled: Bool, now: Date = Date()) async {
        await cancelPlannedTrip(id: plan.id)
        guard enabled, await isAuthorized() else { return }
        let calendar = Calendar.current
        for reminder in PlanReminder.allCases {
            guard let day = reminder.day(for: plan, calendar: calendar),
                  let fire = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: day),
                  fire > now else { continue }

            let content = UNMutableNotificationContent()
            content.sound = .default
            switch reminder {
            case .week:
                content.title = String(localized: "\(plan.flag) \(plan.displayName) in 7 days")
                content.body = String(localized: "One week to go. Time to start packing?")
                content.userInfo = NotificationRoute.plannedTrip(id: plan.id).userInfo
            case .eve:
                content.title = String(localized: "\(plan.flag) Tomorrow: \(plan.displayName)")
                content.body = String(localized: "Have a great trip! Photrail will follow along as you take photos.")
                content.userInfo = NotificationRoute.plannedTrip(id: plan.id).userInfo
            case .back:
                content.title = String(localized: "\(plan.flag) Welcome back!")
                content.body = String(localized: "Relive \(plan.displayName) and share it.")
                content.userInfo = NotificationRoute.tripDuring(start: plan.startDate, end: plan.endDate).userInfo
            }
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: reminder.id(for: plan.id),
                                                content: content, trigger: trigger)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    static func cancelPlannedTrip(id: String) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: PlanReminder.allCases.map { $0.id(for: id) })
    }

    // MARK: - Daily postcard

    static let postcardPrefix = "postcard-"

    /// When tonight's postcard notification should go out.
    enum PostcardTiming: Equatable {
        case at(Date)   // 20:00 today
        case now        // between 20:00 and 22:00: the evening is already here
        case skip       // after 22:00: too late, tomorrow brings a new day
    }

    static func postcardTiming(now: Date, calendar: Calendar = .current) -> PostcardTiming {
        let hour = calendar.component(.hour, from: now)
        if hour < 20, let eight = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now) {
            return .at(eight)
        }
        return hour < 22 ? .now : .skip
    }

    /// Schedules the day's postcard notification. One per day (`postcard-yyyyMMdd`): running
    /// it again for the same day replaces the request, so checks can repeat freely. Only call
    /// it once there are photos from the day — see `AppViewModel.checkTodaysPostcard()`.
    /// - Parameter immediately: for testing from Profile.
    static func schedulePostcard(day: Date, dayNumber: Int?, flag: String, place: String,
                                 now: Date = Date(), immediately: Bool = false) async {
        guard await isAuthorized() else { return }
        let identifier = postcardPrefix + postcardDayKey(day)

        // Already delivered today? Then the user has seen it — never send the day twice.
        if !immediately {
            let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
            if delivered.contains(where: { $0.request.identifier == identifier }) { return }
        }

        let trigger: UNNotificationTrigger?
        switch immediately ? .now : postcardTiming(now: now) {
        case .skip: return
        case .now:  trigger = nil
        case .at(let date):
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        }

        let content = UNMutableNotificationContent()
        content.title = dayNumber.map { String(localized: "\(flag) Day \($0) in \(place)") }
            ?? String(localized: "\(flag) Today in \(place)")
        content.body = String(localized: "Your day is ready to be a postcard.")
        content.sound = .default
        content.userInfo = NotificationRoute.postcard(day: Calendar.current.startOfDay(for: day)).userInfo
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Removes every pending postcard notification (the toggle was turned off).
    static func cancelAllPostcards() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(NotificationService.postcardPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private static func postcardDayKey(_ day: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static func isAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }
}

/// Presents nudges while the app is foregrounded, and routes taps.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// Tapping a nudge lands on what it's about, rather than wherever the app happened to be.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard let route = NotificationRoute(userInfo: response.notification.request.content.userInfo)
        else { return }
        await MainActor.run {
            let router = IntentRouter.shared
            switch route {
            case .trip(let id):  router.pendingTripID = id
            case .yearRecap:     router.openYearRecap = true
            case .map:           router.pendingTab = .map
            case .plannedTrip(let id):
                router.pendingTab = .today
                router.pendingPlannedTripID = id
            case .tripDuring(let start, let end):
                router.pendingTab = .today
                router.pendingTripDuring = start...end
            case .postcard(let day):
                router.pendingPostcardDay = day
            }
        }
    }
}
