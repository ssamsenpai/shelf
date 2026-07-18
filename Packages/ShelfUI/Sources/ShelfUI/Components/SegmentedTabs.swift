import SwiftUI

/// The Folders / Tags switch in the sidebar. A plain system picker, because that is
/// what Apple would ship and it inherits the sidebar material correctly.
public struct SegmentedTabs<Value: Hashable>: View {
    private let options: [(value: Value, title: String)]
    @Binding private var selection: Value

    public init(selection: Binding<Value>, options: [(value: Value, title: String)]) {
        self._selection = selection
        self.options = options
    }

    public var body: some View {
        Picker("", selection: $selection) {
            ForEach(options, id: \.value) { option in
                Text(option.title).tag(option.value)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}
