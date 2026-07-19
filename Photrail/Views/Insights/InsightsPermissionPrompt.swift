import SwiftUI

/// The late opt-in card shown inside a trip when the Insights module is off. Tapping
/// "Enable Insights" flips the flag and presents the native Health permission sheet.
struct InsightsPermissionPrompt: View {
    var onEnable: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.pink)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trip Insights").font(.headline)
                    Text("Powered by Apple Health").font(.caption).foregroundStyle(.secondary)
                }
            }

            Text("See your heart rate, climbs, workouts, and energy from this trip. Everything is read from Apple Health and stays on your device.")
                .font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onEnable) {
                Text("Enable Insights")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
        }
        .padding(AppCard.padding)
        .card()
        .padding(.horizontal, 20)
    }
}

/// Shown when Insights is enabled but Health returned no readable data — which, because
/// HealthKit hides read-denial, means either the user declined or there's genuinely no
/// data for these dates. Offers a way into Settings without assuming which.
struct InsightsEmptyState: View {
    var onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "heart.slash").foregroundStyle(.secondary)
                Text("No health data for these dates").font(.subheadline.weight(.semibold))
            }
            Text("If you expected insights here, check that Photrail has access in the Health app.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Settings", action: onOpenSettings)
                .font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppCard.padding)
        .card()
        .padding(.horizontal, 20)
    }
}
