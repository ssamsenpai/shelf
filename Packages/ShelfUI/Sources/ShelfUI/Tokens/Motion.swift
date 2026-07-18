import SwiftUI

/// Two springs, centralized. Nothing else animates by hand.
public enum Motion {
    /// Taps, hovers, small state changes.
    public static let snappy = Animation.spring(response: 0.28, dampingFraction: 0.82)
    /// Larger transitions, folder opening, tray reveal.
    public static let smooth = Animation.spring(response: 0.45, dampingFraction: 0.86)
    /// Substitute used when Reduce Motion is on.
    public static let crossFade = Animation.easeInOut(duration: 0.18)
}

public extension View {
    /// Applies `animation`, or a cross fade when the user has asked for reduced motion.
    func shelfAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(ShelfAnimationModifier(animation: animation, value: value))
    }
}

private struct ShelfAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? Motion.crossFade : animation, value: value)
    }
}
