import SwiftUI

/// A floating segmented control on real Liquid Glass.
///
/// Each segment carries its own glass effect and shares a `GlassEffectContainer`,
/// which is what lets neighbours merge and the selection morph between them. Glass
/// belongs to the functional layer, so this is only ever used for controls that
/// float above content, never on the content itself.
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

    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(selection: Binding<Value>, options: [Option]) {
        self._selection = selection
        self.options = options
    }

    public var body: some View {
        GlassEffectContainer(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                ForEach(options) { option in
                    segment(for: option)
                }
            }
        }
        .shelfAnimation(Motion.snappy, value: selection)
    }

    private func segment(for option: Option) -> some View {
        let isSelected = option.value == selection

        return Button {
            selection = option.value
        } label: {
            Label(option.title, systemImage: option.symbol)
                .labelStyle(.titleAndIcon)
                .font(.callout)
                .foregroundStyle(isSelected ? Color.shelfAccent : .secondary)
                .padding(.horizontal, Spacing.m)
                .frame(height: 34)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isSelected ? .regular.tint(.shelfAccent.opacity(0.18)).interactive() : .regular.interactive(),
            in: .capsule
        )
        .glassEffectID(option.value, in: namespace)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
