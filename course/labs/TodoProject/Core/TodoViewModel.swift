import Foundation
#if !TODO_HOST
import Observation
#endif

@MainActor
#if !TODO_HOST
@Observable
#endif
final class TodoViewModel {
    private(set) var items: [Todo] = []
    private(set) var isDirty = false
    private(set) var maySave = false
    private(set) var storageError: String?
    private(set) var validationError: String?
    private let store: any TodoStoring

    init(store: any TodoStoring) { self.store = store }
    var remainingCount: Int { items.filter { !$0.isComplete }.count }

    // A reload must never silently replace a failed-save draft.
    @discardableResult func load() -> Bool {
        guard !isDirty else {
            storageError = "Unsaved changes: retry saving before reloading."
            return false
        }
        do {
            let loaded = try store.load()
            try Todo.validate(loaded.items)
            items = loaded.items
            maySave = true
            isDirty = loaded.needsMigrationSave
            storageError = nil
            return true
        } catch {
            maySave = false
            storageError = "Could not read tasks. The original file is preserved; repair a copy and retry loading."
            return false
        }
    }

    @discardableResult func add(title: String, id: UUID = UUID()) -> Bool {
        change {
            var next = items
            next.append(try Todo(id: id, title: title))
            return next
        }
    }

    @discardableResult func rename(id: UUID, to title: String) -> Bool {
        change {
            var next = items
            guard let index = next.firstIndex(where: { $0.id == id }) else { throw TodoError.unknownID }
            try next[index].rename(to: title)
            return next
        }
    }

    @discardableResult func toggle(id: UUID) -> Bool {
        change {
            var next = items
            guard let index = next.firstIndex(where: { $0.id == id }) else { throw TodoError.unknownID }
            next[index].toggle()
            return next
        }
    }

    @discardableResult func delete(ids: Set<UUID>) -> Bool {
        change {
            guard ids.isSubset(of: Set(items.map(\.id))) else { throw TodoError.unknownID }
            return items.filter { !ids.contains($0.id) }
        }
    }

    @discardableResult func move(from offsets: IndexSet, to destination: Int) -> Bool {
        change { try movedTodos(items, from: offsets, to: destination) }
    }

    @discardableResult func save() -> Bool {
        guard maySave else {
            storageError = "Saving is blocked until the existing file loads successfully."
            return false
        }
        do {
            try store.save(items)
            isDirty = false
            storageError = nil
            return true
        } catch {
            isDirty = true
            storageError = "Tasks changed in memory but could not be saved. Retry Save; keep the app open."
            return false
        }
    }

    // Bool reports command validity. Durability is reported separately by isDirty/storageError.
    private func change(_ build: () throws -> [Todo]) -> Bool {
        guard maySave else {
            storageError = "Changes are blocked until the existing file loads successfully."
            return false
        }
        do {
            let next = try build()
            try Todo.validate(next)
            items = next
            isDirty = true
            validationError = nil
            save()
            return true
        } catch {
            validationError = Self.message(for: error)
            return false
        }
    }

    private static func message(for error: Error) -> String {
        switch error {
        case TodoError.emptyTitle: return "Enter a task title."
        case TodoError.titleTooLong: return "Use at most 80 characters."
        case TodoError.duplicateID: return "That task identity already exists."
        case TodoError.unknownID: return "The task no longer exists. Close the editor and try again."
        default: return "The change was rejected; tasks were left unchanged."
        }
    }
}
