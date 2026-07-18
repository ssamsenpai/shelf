import SwiftUI

/// A soft blurred fade at the bottom of a scrolling view, so content dissolves
/// under a floating control instead of colliding with it.
///
/// The blur is masked by a gradient rather than drawn as a hard band, which is what
/// keeps it from reading as a shadow or a border. Purely decorative, so it never
/// takes hit testing.
public struct BottomScrim: View {
    private let height: CGFloat

    public init(height: CGFloat = 128) {
        self.height = height
    }

    public var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.6), location: 0.45),
                        .init(color: .black, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(height: height)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
