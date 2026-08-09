import Foundation

/// Pure easing maths for animations that have to be *sampled* rather than played.
///
/// SwiftUI's `Animation` can't be evaluated at an arbitrary time, so an exportable card can't
/// use it. These take a global progress (0…1 across the whole clip) and return a value, with
/// no state anywhere — which is what makes the exported video and the live preview identical.
enum Easing {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    /// Closed-form approximation of a damped spring — overshoots once, then settles.
    /// Roughly matches `.spring(response: 0.5, dampingFraction: 0.7)`.
    case spring

    func apply(_ t: Double) -> Double {
        let t = min(max(t, 0), 1)
        switch self {
        case .linear:    return t
        case .easeIn:    return t * t
        case .easeOut:   return 1 - pow(1 - t, 3)
        case .easeInOut: return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
        case .spring:
            if t >= 1 { return 1 }
            let decay = exp(-6 * t)
            return 1 - decay * cos(9 * t)
        }
    }
}

/// A slice of the timeline. Maps a global progress onto a local 0…1 so each element can be
/// choreographed independently — "the title arrives between 38% and 55% of the clip".
struct Ramp {
    let start: Double
    let end: Double
    var easing: Easing = .easeOut

    init(_ start: Double, _ end: Double, easing: Easing = .easeOut) {
        self.start = start
        self.end = end
        self.easing = easing
    }

    /// Eased 0…1 for this ramp at the given global progress.
    func value(at progress: Double) -> Double {
        guard end > start else { return progress >= end ? 1 : 0 }
        let local = (progress - start) / (end - start)
        return easing.apply(min(max(local, 0), 1))
    }

    /// Eased interpolation between two values.
    func interpolate(_ from: Double, _ to: Double, at progress: Double) -> Double {
        from + (to - from) * value(at: progress)
    }
}
