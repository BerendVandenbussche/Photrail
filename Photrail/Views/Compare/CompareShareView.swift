import SwiftUI

/// "Compare with a friend": a QR code of your compare link, and the same link to send.
/// The friend scans it with the iPhone camera — no camera permission needed here.
struct CompareShareView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @AppStorage("compareName") private var name = ""

    private var url: URL { appVM.compareURL(name: name) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 6) {
                        Text("Compare with a friend")
                            .font(.title2.weight(.bold))
                        Text("Your friend scans this with their iPhone camera and sees where you've both been.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 12)

                    qrCard

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your name (optional)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("First name", text: $name)
                            .textContentType(.givenName)
                            .submitLabel(.done)
                            .padding(12)
                            .card(cornerRadius: AppCard.chipRadius)
                    }

                    ShareLink(item: url,
                              subject: Text("Compare our travels"),
                              message: Text("Compare our travels in Photrail")) {
                        Label("Send link", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.white)
                    }

                    Label("Only your countries are in the code. Nothing is uploaded.",
                          systemImage: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var qrCard: some View {
        VStack(spacing: 12) {
            if let image = QRCode.image(for: url.absoluteString) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 240)
                    .accessibilityLabel(Text("QR code"))
            }
            Text(verbatim: "\(appVM.profileEmoji) \(L.countries(appVM.stats.countryCount))")
                .font(.headline)
                .foregroundStyle(.black)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        // Always white: a QR code needs dark modules on a light background to scan.
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
    }
}
