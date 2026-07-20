import SwiftData
import SwiftUI
import ShelfUI

/// Adds a link to the library. Title is optional: with link previews on, Shelf fills
/// it from the page, otherwise the domain stands in.
struct AddLinkSheet: View {
    let actions: LibraryActions
    let defaultCategory: ShelfCategory?

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ShelfCategory.createdAt) private var categories: [ShelfCategory]

    @State private var urlString: String = ""
    @State private var title: String = ""
    @State private var categoryID: UUID?
    @State private var isAdding = false

    @AppStorage(LinkPreviewService.settingKey) private var linkPreviews = false

    private var chosenCategory: ShelfCategory? {
        categories.first { $0.id == categoryID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text("Add Link")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: Spacing.m) {
                field("Address") {
                    TextField("example.com", text: $urlString)
                        .textFieldStyle(.roundedBorder)
                }

                field("Title") {
                    TextField("Optional", text: $title)
                        .textFieldStyle(.roundedBorder)
                }

                field("Collection") {
                    Picker("", selection: $categoryID) {
                        Text("No Collection").tag(UUID?.none)
                        ForEach(categories) { category in
                            Text(category.name).tag(UUID?.some(category.id))
                        }
                    }
                    .labelsHidden()
                }
            }

            if !linkPreviews {
                Text("Link previews are off, so Shelf will not fetch the page image. You can turn them on in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Add") { add() }
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(urlString.trimmingCharacters(in: .whitespaces).isEmpty || isAdding)
            }
        }
        .padding(Spacing.xl)
        .frame(width: 420)
        .onAppear { categoryID = defaultCategory?.id }
    }

    private func field<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func add() {
        isAdding = true
        let address = urlString
        let givenTitle = title
        let category = chosenCategory

        Task {
            await actions.addLink(address, title: givenTitle, into: category)
            dismiss()
        }
    }
}
