import SwiftUI

/// Explains why photos can arrive without coordinates, and how to make the camera
/// record them from here on.
///
/// Exists because of a real support thread: someone reported that Photrail found none
/// of their trips, and it turned out their camera had never had Location Services on.
/// Nothing in the app said so — an untagged library and an empty one looked the same —
/// so they spent their time suspecting the app rather than their camera settings.
struct LocationDataGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("Photrail reads the coordinates your camera saves inside each photo. If your camera wasn't allowed to use your location, the photo has no coordinates and there's no way to tell where it was taken.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Turn it on for the camera")
                            .font(.headline)

                        step(1, "Open Settings on your iPhone.")
                        step(2, "Tap Privacy & Security, then Location Services.")
                        step(3, "Turn Location Services on if it's off.")
                        step(4, "Scroll down to Camera and tap it.")
                        step(5, "Choose While Using the App, and turn on Precise Location.")

                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text("Open Settings")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 4)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Good to know")
                            .font(.headline)

                        note("This only affects photos you take from now on. Coordinates can't be added to photos afterwards, because the information was never recorded.")
                        note("Photos sent to you through most messaging apps and social networks arrive without coordinates — those apps strip the location before sending.")
                        note("Screenshots and downloaded images never have coordinates.")
                        note("Photos imported from a camera or AirDropped from another iPhone keep theirs.")
                    }

                    Text("You can add trips by hand in the meantime, from the Places tab.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .navigationTitle("Why are my photos missing?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func note(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Shown on the dashboard when Photrail can only place a small fraction of a large
/// library. See `AppViewModel.shouldWarnAboutUntaggedPhotos` for when that is.
struct UntaggedPhotosNotice: View {
    let untaggedCount: Int
    let placedCount: Int
    var onDismiss: () -> Void

    @State private var showGuide = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "location.slash")
                    .font(.system(size: 22))
                    .foregroundStyle(.orange)
                Text("Most of your photos have no location")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Circle().fill(.gray.opacity(0.15)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Dismiss"))
            }

            // Both numbers, not a percentage: "placed 312 of 14,206" is checkable against
            // what they see in Photos, and makes clear that the missing trips are missing
            // because the photos never carried coordinates, not because Photrail skipped them.
            Text("Photrail placed \(placedCount.formatted()) of your photos on the map. The other \(untaggedCount.formatted()) carry no coordinates, so any trips in them can't be detected.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button { showGuide = true } label: {
                Label("Why is this?", systemImage: "questionmark.circle")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        }
        .padding(AppCard.padding)
        .card()
        .sheet(isPresented: $showGuide) { LocationDataGuideView() }
    }
}

#Preview {
    LocationDataGuideView()
}

extension View {
    /// Attaches the debug-only long-press that forces `UntaggedPhotosNotice` on.
    /// A no-op in Release, so the shipped build carries neither the gesture nor the handler.
    func debugForceUntaggedNotice(_ action: @escaping () -> Void) -> some View {
#if DEBUG
        simultaneousGesture(LongPressGesture(minimumDuration: 1.5).onEnded { _ in action() })
#else
        self
#endif
    }
}
