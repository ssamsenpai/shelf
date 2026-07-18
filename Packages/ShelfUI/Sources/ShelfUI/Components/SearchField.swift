import SwiftUI

/// Sidebar search. Focus is the only state that draws a border, because there it
/// carries meaning.
public struct SearchField: View {
    private let prompt: String
    @Binding private var text: String
    @FocusState private var focused: Bool

    public init(text: Binding<String>, prompt: String = "Search") {
        self._text = text
        self.prompt = prompt
    }

    public var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .imageScale(.small)

            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .focused($focused)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.xs + 2)
        .background(Color.shelfWell, in: .shelf(Radius.small))
        .overlay {
            RoundedRectangle.shelf(Radius.small)
                .strokeBorder(Color.shelfAccent, lineWidth: focused ? 2 : 0)
        }
        .shelfAnimation(Motion.snappy, value: focused)
        .onTapGesture { focused = true }
    }
}
