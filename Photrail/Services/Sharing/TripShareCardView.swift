import SwiftUI

/// A branded, render-ready share card for a single trip. 9:16, photo-backed.
struct TripShareCardView: View {
    let trip: Trip
    var cover: UIImage?

    static let canvasSize = CGSize(width: 360, height: 640)

    private static let brandTop = Color(red: 0.07, green: 0.09, blue: 0.24)
    private static let brandBottom = Color(red: 0.22, green: 0.13, blue: 0.42)
    private static let accent = Color(red: 0.6, green: 0.55, blue: 1.0)

    var body: some View {
        ZStack {
            background
            content
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
    }

    @ViewBuilder
    private var background: some View {
        if let cover {
            Image(uiImage: cover)
                .resizable()
                .scaledToFill()
                .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
                .clipped()
                .overlay(LinearGradient(colors: [.black.opacity(0.25), .black.opacity(0.8)],
                                        startPoint: .top, endPoint: .bottom))
        } else {
            LinearGradient(colors: [Self.brandTop, Self.brandBottom],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer()
            headline
            Spacer(minLength: 20)
            statsRow
            footer.padding(.top, 18)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: 7) {
            LogoMark(color: .white).frame(width: 18, height: 18)
            Text("Photrail")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
            Spacer()
            Text(yearText)
                .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(trip.dateRangeText.uppercased())
                .font(.system(size: 12, weight: .bold)).tracking(1.6)
                .foregroundStyle(Self.accent)
            Text("\(trip.flag) \(trip.country)")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2).minimumScaleFactor(0.5)
                .fixedSize(horizontal: false, vertical: true)
            if !trip.cities.isEmpty {
                Text(trip.cities.prefix(4).joined(separator: " · "))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            ForEach(statItems, id: \.1) { value, label in
                VStack(spacing: 3) {
                    Text(value)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6).lineLimit(1)
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.white.opacity(0.12)))
    }

    private var statItems: [(String, String)] {
        var items: [(String, String)] = [
            ("\(trip.cities.count)", trip.cities.count == 1 ? "City" : "Cities"),
            ("\(trip.photoCount)", "Photos"),
            (trip.durationText.replacingOccurrences(of: " days", with: "")
                              .replacingOccurrences(of: " day", with: ""), "Days")
        ]
        if trip.routeDistanceKm >= 1 {
            items.insert(("\(Int(trip.routeDistanceKm).formatted())", "km"), at: 2)
        }
        if let peak = trip.highestAltitudeText, (trip.highestAltitude ?? 0) >= 1000 {
            items.append((peak.replacingOccurrences(of: " m", with: ""), "Peak (m)"))
        }
        return Array(items.prefix(4))
    }

    private var footer: some View {
        Text("Your travel history, automatically")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.6))
    }

    private var yearText: String {
        let f = DateFormatter(); f.dateFormat = "yyyy"
        return f.string(from: trip.startDate)
    }
}
