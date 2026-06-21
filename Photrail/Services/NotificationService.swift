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
        content.title = "\(flag) Welcome to \(name)!"
        content.body = "A new country for your map — enjoy your trip! ✈️"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "new-country-\(code)",
            content: content,
            trigger: nil   // deliver as soon as possible
        )
        try? await center.add(request)
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
