import SwiftUI

/// Compact in-dashboard banner showing live scan progress.
/// Sits at the top of the dashboard and disappears when the scan completes.
struct ScanBanner: View {
    let progress: AppViewModel.ScanProgress
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 12) {
            // Animated spinner / checkmark
            ZStack {
                switch progress {
                case .scanning, .geocoding:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.8)
                case .complete:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                case .failed:
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.white)
                default:
                    EmptyView()
                }
            }
            .frame(width: 22, height: 22)

            // Label + sub-label
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .contentTransition(.numericText())
                    .animation(.spring(), value: subtitle)
            }

            Spacer()

            // Progress pill
            if let pct = percentage {
                Text(pct)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.85))
                    .contentTransition(.numericText())
                    .animation(.spring(), value: pct)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(bannerColor.gradient)
        }
        .scaleEffect(appeared ? 1 : 0.95)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4)) { appeared = true }
        }
    }

    private var title: String {
        switch progress {
        case .scanning:   return "Scanning photo library"
        case .geocoding:  return "Identifying locations"
        case .complete:   return "All done"
        case .failed:     return "Scan failed"
        case .idle:       return ""
        }
    }

    private var subtitle: String {
        switch progress {
        case .scanning(let p, let found):
            return "\(found) geotagged photos found"
        case .geocoding(let p, let total):
            let done = Int(Double(total) * p)
            return "\(done) of \(total) locations resolved"
        case .complete:
            return "Your travel map is up to date"
        case .failed(let msg):
            return msg
        case .idle:
            return ""
        }
    }

    private var percentage: String? {
        switch progress {
        case .scanning(let p, _) where p > 0:
            return p.formatted(.percent.precision(.fractionLength(0)))
        case .geocoding(let p, _):
            return p.formatted(.percent.precision(.fractionLength(0)))
        default:
            return nil
        }
    }

    private var bannerColor: Color {
        switch progress {
        case .complete: return .green
        case .failed:   return .red
        default:        return Color(red: 0.31, green: 0.27, blue: 0.9)
        }
    }
}
