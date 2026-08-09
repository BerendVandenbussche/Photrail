import SwiftUI

/// Plays the shareable achievement card on a loop and exports it as a video.
///
/// The preview drives `AchievementVideoCardView` from a `TimelineView`, while the export
/// samples the very same view frame by frame. Because the card is a pure function of
/// progress, what plays here and what lands in the file are identical by construction.
struct AchievementVideoPreview: View {
    let achievement: Achievement

    @Environment(\.dismiss) private var dismiss

    @State private var startDate = Date()
    @State private var exporting = false
    @State private var exportProgress: Double = 0
    @State private var errorMessage: String?

    private let config = ShareVideoRenderer.Config()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                SharePreviewCanvas(size: AchievementVideoCardView.canvasSize) {
                    loopingCard
                }

                shareButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
            .navigationTitle("Share achievement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay { if exporting { exportOverlay } }
            .alert("Couldn't create the video", isPresented: errorBinding) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .interactiveDismissDisabled(exporting)
    }

    // MARK: - Preview

    private var loopingCard: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            // Hold on the finished card for a beat before looping, so the brand — which
            // resolves last — is actually readable.
            let cycle = config.duration + 1.2
            let progress = min(elapsed.truncatingRemainder(dividingBy: cycle) / config.duration, 1)

            AchievementVideoCardView(achievement: achievement, progress: progress)
        }
        .onAppear { startDate = Date() }
    }

    // MARK: - Export

    private var shareButton: some View {
        Button { Task { await export() } } label: {
            Label("Share as video", systemImage: "square.and.arrow.up")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
        }
        .disabled(exporting)
    }

    private var exportOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView(value: exportProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 180)
                Text("Creating video…")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(28)
            .background(Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        // Rendering keeps the main actor busy throughout, so block interaction rather than
        // letting the UI feel broken.
        .transition(.opacity)
    }

    private func export() async {
        exporting = true
        exportProgress = 0
        defer { exporting = false }

        do {
            let url = try ShareVideoFile.makeURL(named: "Photrail — \(achievement.id)")
            let output = try await ShareVideoRenderer.export(
                config: config,
                outputURL: url,
                onProgress: { exportProgress = $0 }
            ) { progress in
                AchievementVideoCardView(achievement: achievement, progress: progress)
            }
            // Cleaned up only once the sheet is done: Instagram and TikTok read the file
            // lazily after their extension launches, so deleting any earlier ships a 0-byte
            // video. The handler fires on cancel too.
            SharePresenter.present([output]) {
                ShareVideoFile.remove(output)
            }
        } catch is CancellationError {
            // Nothing to report — the user backed out.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }
}

#Preview {
    AchievementVideoPreview(achievement: AchievementCatalog.all[2])
}
