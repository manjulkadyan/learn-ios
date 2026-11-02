import SwiftUI

struct LayoutPanel: View {
    enum Field: Hashable { case name, note }
    @Environment(\.layoutDirection) private var direction
    @State private var name = ""
    @State private var note = ""
    @State private var rtl = false
    @State private var error = ""
    @FocusState private var field: Field?
    @AccessibilityFocusState private var errorFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Toggle("Force RTL fixture", isOn: $rtl)
                    BaselineFlow() {
                        Text("Small").font(.caption)
                        Text("Large baseline").font(.title)
                        Text("Forced next row").layoutValue(key: RowBreakKey.self, value: true)
                        Text("A longer label that can wrap").font(.body)
                    }
                    .environment(\.layoutDirection, rtl ? .rightToLeft : direction)
                    // Orthogonal axes: native scroll recognizers arbitrate, no blanket drag.
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(0..<8) { i in
                                Button("Fixture \(i)") { note = "Selected fixture \(i)" }
                                    .buttonStyle(.bordered).id(i)
                            }
                        }
                    }
                    .accessibilityLabel("Horizontal fixture choices")
                    TextField("Synthetic name", text: $name)
                        .id(Field.name).focused($field, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { field = .note; proxy.scrollTo(Field.note, anchor: .center) }
                    TextField("Synthetic note", text: $note)
                        .id(Field.note).focused($field, equals: .note)
                        .submitLabel(.done).onSubmit { field = nil }
                    if !error.isEmpty {
                        Text(error).foregroundStyle(.red)
                            .accessibilityFocused($errorFocused)
                    }
                    Button("Validate name") {
                        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            error = "Enter a synthetic name."
                            field = nil
                            errorFocused = true
                        } else { error = ""; errorFocused = false; field = nil }
                    }
                    Text("Keyboard editing focus and assistive focus are separate requests.")
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Previous") { field = .name; proxy.scrollTo(Field.name, anchor: .center) }
                    Button("Next") { field = .note; proxy.scrollTo(Field.note, anchor: .center) }
                    Button("Done") { field = nil }
                }
            }
        }
    }
}
