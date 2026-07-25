import SwiftUI

/// A branded, render-ready share card for an "On This Day" memory. 9:16, photo-backed.
struct MemoryShareCardView: View {
    let memory: Memory
    var cover: UIImage?

    static let canvasSize = CGSize(width: 360, height: 640)

    private static let gradientTop = Color(red: 0.31, green: 0.27, blue: 0.9)
    private static let gradientBottom = Color(red: 0.55, green: 0.3, blue: 0.85)

    var body: some View {
        ZStack {
            background
            content
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .environment(\.locale, Locale(identifier: "en_US"))   // share cards stay English
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
            LinearGradient(colors: [Self.gradientTop, Self.gradientBottom],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer()
            headline
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
            Text(String(memory.year))
                .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("🕓").font(.system(size: 14))
                Text("ON THIS DAY")
                    .font(.system(size: 12, weight: .heavy)).tracking(1.4)
            }
            .foregroundStyle(Self.gradientBottom)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(.white))

            Text(englishYearsAgo.uppercased())
                .font(.system(size: 12, weight: .bold)).tracking(1.6)
                .foregroundStyle(.white.opacity(0.85))

            Text("\(memory.flag) \(memory.placeText)")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(3).minimumScaleFactor(0.5)
                .fixedSize(horizontal: false, vertical: true)

            Text(englishDate)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private var footer: some View {
        Text("Your travel history, automatically")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.6))
    }

    /// "X years ago" in English (the card stays English regardless of device locale).
    private var englishYearsAgo: String {
        memory.yearsAgo == 1 ? "1 year ago" : "\(memory.yearsAgo) years ago"
    }

    private var englishDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateStyle = .long
        return f.string(from: memory.date)
    }
}
