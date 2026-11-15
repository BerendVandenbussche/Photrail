import SwiftUI
import UIKit

/// The app's motion vocabulary, so animations feel like one system: short, springy without
/// bouncing on large surfaces, and replaced by a plain cross-fade under Reduce Motion.
enum Motion {
    /// Small things: presses, chips, pins.
    static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.82)
    /// Cards, sheets, camera moves.
    static let smooth = Animation.spring(response: 0.45, dampingFraction: 0.92)
    /// Numbers and progress filling in on first appearance.
    static let reveal = Animation.spring(response: 0.9, dampingFraction: 0.95)
}

// MARK: - Haptics

/// Haptics only where something actually happened: a result, a selection, a snap. Never on
/// scrolling or on plain navigation taps. The system's own haptics setting still applies.
@MainActor
enum Haptics {
    /// Something was earned or saved: an achievement, flights added.
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// A choice changed: a segment, a map pin, a photo snapping to zoom.
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// A quiet confirmation: a photo excluded or restored, a list refreshed.
    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
    }
}

// MARK: - Pressable cards

/// Cards and rows that press in a little under the finger, then spring back.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        PressableBody(configuration: configuration, scale: scale)
    }

    private struct PressableBody: View {
        let configuration: Configuration
        let scale: CGFloat
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
                .opacity(configuration.isPressed ? 0.9 : 1)
                .animation(Motion.snappy, value: configuration.isPressed)
        }
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    /// Presses in slightly; for cards and rows that open something.
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

// MARK: - Counting numbers

/// A whole number that rolls up from zero the first time it's shown in this run of the app,
/// then rolls to each new value. Keyed, so a lazy list rebuilding the view doesn't replay it.
struct CountUpText: View {
    let value: Int
    /// Identifies this number across rebuilds, e.g. "dashboard.countries".
    let key: String
    var format: (Int) -> String = { $0.formatted() }

    @MainActor private static var counted: Set<String> = []

    @State private var shown: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(verbatim: format(shown ?? (Self.counted.contains(key) ? value : 0)))
            .contentTransition(.numericText(value: Double(shown ?? 0)))
            .accessibilityLabel(Text(verbatim: format(value)))
            .onAppear {
                guard shown == nil else { return }
                if Self.counted.contains(key) || reduceMotion || value == 0 {
                    shown = value
                } else {
                    shown = 0
                    Self.counted.insert(key)
                    withAnimation(Motion.reveal.delay(0.15)) { shown = value }
                }
            }
            .onChange(of: value) { _, new in
                withAnimation(Motion.smooth) { shown = new }
            }
    }
}

// MARK: - Loading shimmer

/// A soft light sweeping across a placeholder while it loads. Still under Reduce Motion.
struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { geo in
                        let width = geo.size.width
                        LinearGradient(colors: [.clear, .white.opacity(0.22), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: width * 0.6)
                            .offset(x: -width * 0.6 + phase * width * 1.6)
                    }
                    .allowsHitTesting(false)
                    .clipped()
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    /// A loading shimmer; see `Shimmer`.
    func shimmering() -> some View { modifier(Shimmer()) }

    /// The iOS 18 zoom transition from a `matchedTransitionSource`, when there's a namespace.
    @ViewBuilder
    func zoomTransition(sourceID: some Hashable, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            self
        }
    }

    /// Marks the view a zoom transition grows out of and shrinks back into, when there's a namespace.
    @ViewBuilder
    func zoomSource(id: some Hashable, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// Carousel cards that settle in as they reach the middle: a touch smaller and dimmer at
    /// the edges. Nothing under Reduce Motion.
    func carouselItem() -> some View {
        modifier(CarouselItem())
    }
}

private struct CarouselItem: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let still = reduceMotion
        return content.scrollTransition(.interactive, axis: .horizontal) { view, phase in
            view
                .scaleEffect(still || phase.isIdentity ? 1 : 0.94)
                .opacity(still || phase.isIdentity ? 1 : 0.7)
        }
    }
}

// MARK: - Progress filling in

/// Hands `content` a fraction that grows from zero to `value` with a spring when it first
/// appears, then follows changes. Straight to `value` under Reduce Motion.
struct RevealedProgress<Content: View>: View {
    let value: Double
    @ViewBuilder let content: (Double) -> Content

    @State private var shown: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content(shown ?? (reduceMotion ? value : 0))
            .onAppear {
                guard shown == nil else { return }
                if reduceMotion {
                    shown = value
                } else {
                    withAnimation(Motion.reveal.delay(0.1)) { shown = value }
                }
            }
            .onChange(of: value) { _, new in
                withAnimation(Motion.smooth) { shown = new }
            }
    }
}

// MARK: - Parallax hero

/// How far a scroll view has scrolled from its resting position: 0 at rest, negative while
/// pulled down, positive scrolled up. Its own object so only the views that read it
/// (`ParallaxHero`, `ScrollFade`) redraw every frame, not the whole page.
@Observable
final class ScrollOffset {
    var y: CGFloat = 0
}

extension View {
    /// Feeds `offset` from this scroll view (iOS 18).
    func trackScrollOffset(_ offset: ScrollOffset) -> some View {
        onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, new in
            offset.y = new
        }
    }

    /// A hero image that scrolls away slower than the page and stretches when pulled down.
    /// Clip it to its own frame first; the stretch grows upward out of that frame.
    func parallaxHero(_ offset: ScrollOffset, height: CGFloat) -> some View {
        modifier(ParallaxHero(offset: offset, height: height))
    }

    /// Fades out over the first `distance` points of scrolling, e.g. a hero's title.
    func scrollFade(_ offset: ScrollOffset, distance: CGFloat = 200) -> some View {
        modifier(ScrollFade(offset: offset, distance: distance))
    }
}

private struct ParallaxHero: ViewModifier {
    let offset: ScrollOffset
    let height: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let y = reduceMotion ? 0 : offset.y
        let pull = max(0, -y)
        content
            .scaleEffect(1 + pull / max(height, 1), anchor: .bottom)
            .offset(y: y > 0 ? y * 0.4 : 0)
    }
}

private struct ScrollFade: ViewModifier {
    let offset: ScrollOffset
    let distance: CGFloat

    func body(content: Content) -> some View {
        content.opacity(Double(min(1, max(0, 1 - offset.y / distance))))
    }
}
