import Foundation
import UserNotifications

/// Local notifications for travel milestones (e.g. arriving in a new country).
enum NotificationService {

    /// Ask for notification permission. Safe to call repeatedly — iOS only prompts once.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
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

        var comps = DateComponents()
        comps.year = year + 1; comps.month = 1; comps.day = 2; comps.hour = 19; comps.minute = 0
        let target = Calendar.current.date(from: comps) ?? Date()
        let trigger: UNNotificationTrigger? = target > Date()
            ? UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            : nil
        let request = UNNotificationRequest(identifier: "year-recap-\(year)", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private static func isAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }
}

/// Lets "new country" notifications appear as a banner even while the app is foregrounded.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
