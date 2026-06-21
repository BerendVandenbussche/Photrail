import SwiftUI

struct PermissionDeniedView: View {
    @Environment(AppViewModel.self) var appVM

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: 52))
                    .foregroundStyle(.red)
            }

            VStack(spacing: 12) {
                Text("Photo Access Required")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("Photrail needs access to your photo library to read location data. Your photos stay on your device.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    appVM.openSettings()
                } label: {
                    Label("Open Settings", systemImage: "gear")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }

                Button("Try Again") {
                    appVM.retryPermission()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    PermissionDeniedView()
        .environment(AppViewModel())
}
