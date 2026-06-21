import SwiftUI

/// A reusable stat card used throughout the dashboard.
struct StatCard: View {
    var icon: String
    var value: String
    var label: String
    var iconColor: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
                Spacer()
            }
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// Two StatCards side-by-side in a horizontal pair.
struct StatCardPair: View {
    var left: (icon: String, value: String, label: String, color: Color)
    var right: (icon: String, value: String, label: String, color: Color)

    var body: some View {
        HStack(spacing: 12) {
            StatCard(icon: left.icon, value: left.value, label: left.label, iconColor: left.color)
            StatCard(icon: right.icon, value: right.value, label: right.label, iconColor: right.color)
        }
    }
}

#Preview {
    StatCard(icon: "globe", value: "23", label: "Countries visited", iconColor: .blue)
        .frame(width: 160)
        .padding()
}
