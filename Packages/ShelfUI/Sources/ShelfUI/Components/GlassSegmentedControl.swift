import SwiftUI

/// A floating segmented control on real Liquid Glass.
///
/// One glass capsule holds the whole strip, with a solid indicator that slides
/// between segments. Giving each segment its own glass effect instead would read as
/// several separate pills rather than one control, and glass sampling glass is the
/// thing the design rules rule out.
///
/// Glass belongs to the functional layer, so this is only used for controls that
/// float above content, never on content itself.
public struct GlassSegmentedControl<Value: Hashable & Sendable>: View {
    public struct Option: Identifiable {
        public let value: Value
        public let symbol: String
        public let title: String

        public var id: Value { value }

        public init(value: Value, symbol: String, title: String) {
            self.value = value
            self.symbol = symbol
            self.title = title
        }
    }

    @Binding private var selection: Value
    private let options: [Option]

    @Namespace private var indicator

    public init(selection: Binding<Value>, options: [Option]) {
        self._selection = selection
        self.options = options
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                segment(for: option)
            }
        }
        .padding(Spacing.xs)
        .glassEffect(.regular.interactive(), in: .capsule)
        .shelfAnimation(Motion.snappy, value: selection)
    }

    private func segment(for option: Option) -> some View {
        let isSelected = option.value == selection

        return Button {
            selection = option.value
        } label: {
            Text(option.title)
                .font(.callout.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, Spacing.l)
                .frame(height: 30)
                .background {
                    if isSelected {
                        // A raised chip rather than an accent fill, so the label
                        // stays legible and the control reads as one surface.
                        Capsule()
                            .fill(Color.shelfRaised)
                            .shelfShadow(lifted: true)
                            .matchedGeometryEffect(id: "selection", in: indicator)
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
