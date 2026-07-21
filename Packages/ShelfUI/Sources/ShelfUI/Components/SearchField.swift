import SwiftUI

/// Sidebar search. Focus is the only state that draws a border, because there it
/// carries meaning.
public struct SearchField: View {
    private let prompt: String
    /// Bare drops the field's own well and focus ring, for placement inside
    /// chrome that already draws a container, such as a toolbar cluster.
    private let bare: Bool

    @Binding private var text: String
    @FocusState private var focused: Bool

    public init(text: Binding<String>, prompt: String = "Search", bare: Bool = false) {
        self._text = text
        self.prompt = prompt
        self.bare = bare
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
        .padding(.horizontal, bare ? 0 : Spacing.s)
        .padding(.vertical, bare ? 0 : Spacing.xs + 2)
        .background(bare ? .clear : Color.shelfWell, in: .shelf(Radius.small))
        .overlay {
            if !bare {
                RoundedRectangle.shelf(Radius.small)
                    .strokeBorder(Color.shelfAccent, lineWidth: focused ? 2 : 0)
            }
        }
        .shelfAnimation(Motion.snappy, value: focused)
        .onTapGesture { focused = true }
    }
}
