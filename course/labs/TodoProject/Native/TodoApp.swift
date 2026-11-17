import Foundation
import SwiftUI

// Add this file AND Core/*.swift to a separate iOS 17+ App target. No package imports.
@main @MainActor
struct TodoScratchApp: App {
    @State private var model: TodoViewModel
    init() {
        let base = URL.applicationSupportDirectory.appendingPathComponent("TodoScratch", isDirectory: true)
        let model = TodoViewModel(store: FileTodoStore(url: base.appendingPathComponent("tasks.json")))
        model.load()
        _model = State(initialValue: model)
    }
    var body: some Scene { WindowGroup { TodoListScreen(model: model) } }
}

private struct EditTarget: Identifiable {
    let id = UUID() // Identity of the sheet session, allocated on the button action.
    let todoID: UUID?
    let title: String
}

@MainActor
private struct TodoListScreen: View {
    let model: TodoViewModel
    @State private var editor: EditTarget?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("\(model.remainingCount) tasks remaining")
                    if let error = model.storageError {
                        Text(error).foregroundStyle(.red)
                        if model.maySave { Button("Retry Save") { model.save() } }
                        else { Button("Retry Load") { model.load() } }
                    }
                    if model.isDirty && model.storageError == nil {
                        Text("Current tasks need saving, including any loaded migration.")
                        Button("Save Current Tasks") { model.save() }
                    }
                    if let error = model.validationError { Text(error).foregroundStyle(.red) }
                }
                Section("Tasks") {
                    ForEach(model.items) { item in
                        HStack(alignment: .top) {
                            Button { model.toggle(id: item.id) } label: {
                                Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(item.title)
                            .accessibilityValue(item.isComplete ? "Complete" : "Incomplete")
                            .accessibilityHint("Double tap to change completion")
                            Button { editor = EditTarget(todoID: item.id, title: item.title) } label: {
                                Text(item.title).strikethrough(item.isComplete)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Edit \(item.title)")
                        }
                    }
                    .onDelete { offsets in
                        let ids = Set(offsets.compactMap { model.items.indices.contains($0) ? model.items[$0].id : nil })
                        model.delete(ids: ids)
                    }
                    .onMove { model.move(from: $0, to: $1) }
                    if model.items.isEmpty { Text("Add a task to begin.") }
                }
            }
            .navigationTitle("Pocket Tasks")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton().disabled(!model.maySave) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add", systemImage: "plus") { editor = EditTarget(todoID: nil, title: "") }
                        .disabled(!model.maySave)
                }
            }
            .sheet(item: $editor) { target in TodoEditor(model: model, target: target) }
        }
    }
}

@MainActor
private struct TodoEditor: View {
    let model: TodoViewModel
    let target: EditTarget
    @State private var draft: String
    @State private var message: String?
    @FocusState private var titleFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(model: TodoViewModel, target: EditTarget) {
        self.model = model
        self.target = target
        _draft = State(initialValue: target.title)
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Task title", text: $draft, axis: .vertical)
                    .focused($titleFocused)
                    .submitLabel(.done)
                    .onSubmit(commit)
                Text("\(draft.count) characters; maximum 80 after trimming")
                    .foregroundStyle(.secondary)
                if let message { Text(message).foregroundStyle(.red) }
            }
            .navigationTitle(target.todoID == nil ? "Add Task" : "Edit Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: commit) }
            }
            .onAppear { titleFocused = true }
        }
    }
    private func commit() {
        let valid: Bool
        if let id = target.todoID { valid = model.rename(id: id, to: draft) }
        else { valid = model.add(title: draft) }
        if valid { dismiss() }
        else { message = model.validationError ?? model.storageError }
    }
}
