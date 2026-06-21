import SwiftUI

/// Full-screen loading state shown during photo scanning.
struct ScanProgressView: View {
    var progress: Double
    var found: Int
    var label: String

    @State private var rotationAngle: Double = 0
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            // Animated icon
            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(0.1), lineWidth: 4)
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulse ? 1.2 : 1)
                    .opacity(pulse ? 0 : 0.6)
                    .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: pulse)

                Circle()
                    .trim(from: 0, to: max(0.05, progress))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(), value: progress)

                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)
                    .rotationEffect(.degrees(rotationAngle))
            }
            .onAppear {
                pulse = true
            }

            VStack(spacing: 10) {
                Text(label)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                if found > 0 {
                    Text("\(found) geotagged photos found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(.spring(), value: found)
                }

                if progress > 0 {
                    Text(progress.formatted(.percent.precision(.fractionLength(0))))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .contentTransition(.numericText())
                        .animation(.spring(), value: progress)
                }
            }

            Spacer()
            Spacer()
        }
        .padding(32)
    }
}

#Preview {
    ScanProgressView(progress: 0.42, found: 312, label: "Scanning your library…")
}
