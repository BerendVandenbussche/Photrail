import SwiftUI

/// A day's postcard, with ‹ › to the other days of the same trip and a share button.
struct PostcardView: View {
    let request: AppViewModel.PostcardRequest
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    /// The trip's days in its own time zone; set when the view appears.
    @State private var context: AppViewModel.PostcardContext?
    @State private var day: Date?
    @State private var content: PostcardContent?
    @State private var loading = true

    private var days: [Date] { context?.days ?? [] }
    private var tripID: String? { context?.tripID ?? request.tripID }
    private var index: Int? { day.flatMap { days.firstIndex(of: $0) } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                PostcardPreview(content: content, loading: loading,
                                emptyDayNumber: day.map { appVM.postcardDayNumber(day: $0, tripID: tripID) } ?? 1)
                dayPicker
                shareButton
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .navigationTitle("Postcard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .onAppear {
            let context = appVM.postcardContext(for: request)
            self.context = context
            day = context.firstDay
        }
        .task(id: day) { await load() }
        // Dates read in the trip's own zone, like the card's postmark.
        .environment(\.timeZone, context?.calendar.timeZone ?? .current)
    }

    private var dayPicker: some View {
        HStack {
            Button { step(-1) } label: { Image(systemName: "chevron.left") }
                .disabled((index ?? 0) <= 0)
                .accessibilityLabel(Text("Previous day"))
            Spacer()
            if let day {
                Text(day, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.subheadline.weight(.semibold))
            }
            Spacer()
            Button { step(1) } label: { Image(systemName: "chevron.right") }
                .disabled((index ?? days.count) >= days.count - 1)
                .accessibilityLabel(Text("Next day"))
        }
        .font(.headline)
        .padding(.horizontal, 8)
    }

    private var shareButton: some View {
        Button { share() } label: {
            Label("Share postcard", systemImage: "square.and.arrow.up")
                .font(.headline)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
        }
        .disabled(content == nil)
    }

    private func step(_ delta: Int) {
        guard let index, days.indices.contains(index + delta) else { return }
        day = days[index + delta]
    }

    private func load() async {
        guard let day else { return }
        loading = true
        content = nil
        if let postcard = await appVM.makePostcard(day: day, tripID: tripID) {
            let loaded = await PostcardContent.load(for: postcard)
            guard !Task.isCancelled else { return }
            content = loaded
        }
        loading = false
    }

    private func share() {
        guard let content,
              let image = ShareCardRenderer.render(PostcardCardView(content: content),
                                                   baseSize: PostcardCardView.canvasSize,
                                                   opaque: true)
        else { return }
        SharePresenter.present([image])
    }
}

/// The card scaled to the space it gets, or a spinner / empty state in the same frame.
struct PostcardPreview: View {
    let content: PostcardContent?
    var loading = false
    var emptyDayNumber = 1

    var body: some View {
        GeometryReader { geo in
            let canvas = PostcardCardView.canvasSize
            let scale = min(geo.size.width / canvas.width, geo.size.height / canvas.height)
            Group {
                if let content {
                    PostcardCardView(content: content)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                        if loading {
                            ProgressView()
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                                Text("No photos from day \(emptyDayNumber) yet")
                                    .font(.title3.weight(.semibold))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(30)
                        }
                    }
                    .frame(width: canvas.width, height: canvas.height)
                }
            }
            .scaleEffect(scale)
            .frame(width: canvas.width * scale, height: canvas.height * scale)
            .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
