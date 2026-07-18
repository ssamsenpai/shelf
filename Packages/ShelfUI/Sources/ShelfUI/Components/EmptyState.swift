import SwiftUI

/// A calm, centered empty state: a symbol in a soft container, a short title, one
/// supporting line, one action. No paragraphs, no illustration clutter.
public struct EmptyState: View {
    private let symbol: String
    private let title: String
    private let message: String
    private let actionTitle: String?
    private let action: (() -> Void)?
    private let hint: String?

    public init(
        symbol: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        hint: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.hint = hint
        self.action = action
    }

    public var body: some View {
        VStack(spacing: Spacing.l) {
            RoundedRectangle.shelf(Radius.large)
                .fill(Color.shelfWell)
                .frame(width: 64, height: 64)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(.secondary)
                }

            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
            }

            if let hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: 340)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
