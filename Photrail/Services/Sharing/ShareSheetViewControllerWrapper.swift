import SwiftUI
import UIKit

/// Presents the system share sheet via UIKit, on top of whatever is currently shown.
///
/// We present directly rather than through a SwiftUI `.sheet`, because the share
/// buttons live inside views that are themselves presented as sheets — and presenting
/// one SwiftUI sheet on top of another deadlocks (the UI just hangs).
@MainActor
enum SharePresenter {
    static func present(_ items: [Any]) {
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
                ?? scene.windows.first?.rootViewController
        else { return }

        // Walk to the top-most presented controller (e.g. our composer/recap sheet).
        var top = root
        while let presented = top.presentedViewController { top = presented }

        let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = activity.popoverPresentationController {   // iPad
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        top.present(activity, animated: true)
    }
}
