import SwiftUI

/// The one-time "New in Photrail" sheet. Renders whatever `WhatsNewAnnouncement` it's given;
/// the content lives in `WhatsNew.current`.
struct WhatsNewView: View {
    let announcement: WhatsNewAnnouncement
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(announcement.rows) { row($0) }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 44)
                .padding(.bottom, 20)
            }

            buttons
        }
        .onAppear { appVM.markWhatsNewSeen(announcement) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(announcement.eyebrow)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.tint)
                .textCase(.uppercase)
            Text(announcement.title)
                .font(.largeTitle.weight(.bold))
        }
    }

    private func row(_ row: WhatsNewAnnouncement.Row) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: row.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(row.color.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(row.title).font(.headline)
                Text(row.detail(hasLifetime: appVM.hasLifetime))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            if let action = announcement.action, appVM.canPerform(action.kind) {
                Button {
                    dismiss()
                    // After the sheet is gone: a root sheet can't present on top of itself.
                    Task {
                        try? await Task.sleep(for: .milliseconds(450))
                        appVM.perform(action.kind)
                    }
                } label: {
                    Label { Text(action.title) } icon: { Image(systemName: action.symbol) }
                        .font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
            }
            Button("Later") { dismiss() }
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, 8)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }
}
