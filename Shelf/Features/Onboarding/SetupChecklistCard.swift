import SwiftUI
import ShelfUI

/// A small card at the top of All Items that checks itself off as the user gets
/// set up. It catches people who skipped the welcome flow, then gets out of the
/// way: dismissing it or finishing everything hides it for good.
struct SetupChecklistCard: View {
    let assetCount: Int

    @Environment(AppState.self) private var app

    @AppStorage("didOpenExtensionGuide") private var extensionDone = false
    @AppStorage("didUseQuickShelf") private var quickShelfDone = false
    @AppStorage("didDismissSetupChecklist") private var dismissed = false

    private var assetsDone: Bool { assetCount > 0 }
    private var allDone: Bool { assetsDone && extensionDone && quickShelfDone }

    var body: some View {
        if !dismissed && !allDone {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack {
                    Text("Get set up")
                        .font(.headline)
                    Spacer()
                    Button {
                        dismissed = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Hide this")
                }

                item(done: assetsDone, text: "Add your first assets") {
                    app.requestImport()
                }
                item(done: extensionDone, text: "Enable the browser extension") {
                    app.isPresentingExtensionOnboarding = true
                }
                item(done: quickShelfDone, text: "Press Option-Space to try Quick Shelf") {
                    QuickShelfController.shared.show()
                }
            }
            .padding(Spacing.l)
            .background(Color.shelfRaised, in: RoundedRectangle.shelf(Radius.medium))
            .shelfAnimation(Motion.snappy, value: allDone)
        }
    }

    private func item(done: Bool, text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(done ? Color.shelfAccent : Color.secondary)

                Text(text)
                    .font(.callout)
                    .foregroundStyle(done ? .secondary : .primary)
                    .strikethrough(done, color: .secondary)

                Spacer()

                if !done {
                    Image(systemName: "arrow.forward")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(done)
    }
}
