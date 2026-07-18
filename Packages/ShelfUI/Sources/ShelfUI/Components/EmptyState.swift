import SwiftUI

/// A calm empty state: a symbol, a short line, one action. No paragraphs.
public struct EmptyState: View {
    private let symbol: String
    private let title: String
    private let message: String?
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(
        symbol: String,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.tertiary)

            VStack(spacing: Spacing.xs) {
                Text(title).font(.headline)
                if let message {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.glassProminent)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
