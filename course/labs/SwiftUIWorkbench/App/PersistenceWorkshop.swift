import SwiftUI
import SwiftData
import CoreData
import Observation

@Model
final class PracticeNote {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    init(title: String) {
        id = UUID()
        self.title = title
        createdAt = Date()
    }
}

struct CoreNoteSnapshot: Identifiable, Sendable {
    let id: UUID
    let title: String
    let createdAt: Date
}

@MainActor @Observable
final class CoreDataStore {
    var ready = false
    var status = "Opening synthetic Core Data store…"
    var notes: [CoreNoteSnapshot] = []
    @ObservationIgnored private let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "CoreNote"
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        func attribute(_ name: String, _ type: NSAttributeType) -> NSAttributeDescription {
            let value = NSAttributeDescription()
            value.name = name
            value.attributeType = type
            value.isOptional = false
            return value
        }
        entity.properties = [attribute("id", .UUIDAttributeType), attribute("title", .stringAttributeType),
                             attribute("createdAt", .dateAttributeType)]
        entity.uniquenessConstraints = [["id"]]
        model.entities = [entity]
        container = NSPersistentContainer(name: "SyntheticCoreNotes", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        if inMemory {
            description.type = NSInMemoryStoreType
        } else {
            do {
                let directory = try FileManager.default.url(for: .applicationSupportDirectory,
                    in: .userDomainMask, appropriateFor: nil, create: true)
                    .appendingPathComponent("SwiftUIWorkbench", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                description.url = directory.appendingPathComponent("synthetic.sqlite")
            } catch {
                status = "Store path failed: \(error.localizedDescription)"
                return
            }
        }
        container.persistentStoreDescriptions = [description]
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.loadPersistentStores { [weak self] _, error in
            let failure = error?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let failure { self.status = "Store open failed: \(failure)" }
                else { self.ready = true; self.refresh() }
            }
        }
    }

    func refresh() {
        guard ready else { return }
        do {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CoreNote")
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            notes = try container.viewContext.fetch(request).compactMap { object in
                guard let id = object.value(forKey: "id") as? UUID,
                      let title = object.value(forKey: "title") as? String,
                      let date = object.value(forKey: "createdAt") as? Date else { return nil }
                return CoreNoteSnapshot(id: id, title: title, createdAt: date)
            }
            status = "Fetched \(notes.count) synthetic Core Data notes"
        } catch { status = "Fetch failed: \(error.localizedDescription)" }
    }

    func add(_ title: String) {
        guard ready, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let object = NSEntityDescription.insertNewObject(forEntityName: "CoreNote", into: container.viewContext)
        object.setValue(UUID(), forKey: "id")
        object.setValue(title, forKey: "title")
        object.setValue(Date(), forKey: "createdAt")
        saveViewContext()
    }

    private func find(_ id: UUID) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CoreNote")
        request.predicate = NSPredicate(format: "id == %@", id as NSUUID)
        request.fetchLimit = 1
        return try container.viewContext.fetch(request).first
    }
    func rename(_ id: UUID) {
        do {
            guard ready, let object = try find(id) else { return }
            let old = object.value(forKey: "title") as? String ?? ""
            object.setValue(old.hasPrefix("Edited: ") ? String(old.dropFirst(8)) : "Edited: " + old, forKey: "title")
            saveViewContext()
        } catch { status = "Update failed: \(error.localizedDescription)" }
    }
    func delete(_ id: UUID) {
        do {
            guard ready, let object = try find(id) else { return }
            container.viewContext.delete(object)
            saveViewContext()
        } catch { status = "Delete failed: \(error.localizedDescription)" }
    }
    private func saveViewContext() {
        do { try container.viewContext.save(); refresh() }
        catch {
            container.viewContext.rollback()
            status = "Save failed; context rolled back: \(error.localizedDescription)"
        }
    }

    func addInBackground() async {
        guard ready else { return }
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        do {
            try await context.perform {
                let object = NSEntityDescription.insertNewObject(forEntityName: "CoreNote", into: context)
                object.setValue(UUID(), forKey: "id")
                object.setValue("Background fixture", forKey: "title")
                object.setValue(Date(), forKey: "createdAt")
                try context.save()
                // No managed object leaves this context's queue.
            }
            container.viewContext.processPendingChanges()
            refresh()
            status = "Background save complete; UI context merges saves and fetches value snapshots"
        } catch { status = "Background save failed: \(error.localizedDescription)" }
    }
}

struct PersistenceWorkshop: View {
    @State private var mode = 0
    var body: some View {
        NavigationStack {
            VStack {
                Picker("Independent stores", selection: $mode) {
                    Text("Core Data").tag(0)
                    Text("SwiftData").tag(1)
                }.pickerStyle(.segmented).padding(.horizontal)
                if mode == 0 { CoreDataEditor() } else { SwiftDataEditor() }
            }.navigationTitle("Persistence workbench")
        }
    }
}

private struct CoreDataEditor: View {
    @Environment(AppServices.self) private var services
    @State private var title = "Synthetic note"
    @State private var addingInBackground = false
    var body: some View {
        let store = services.coreData
        Form {
            Section("Programmatic model and view context") {
                TextField("Title", text: $title)
                Button("Insert and save") { store.add(title) }.disabled(!store.ready || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Background context insert") {
                    addingInBackground = true
                    Task { await store.addInBackground(); addingInBackground = false }
                }.disabled(!store.ready || addingInBackground)
                Button("Fetch current values") { store.refresh() }.disabled(!store.ready)
                Text(store.status).font(.caption)
            }
            Section("Value snapshots, not managed objects") {
                ForEach(store.notes) { note in
                    VStack(alignment: .leading) {
                        Text(note.title)
                        Text(note.createdAt, format: .dateTime).font(.caption)
                        HStack {
                            Button("Rename") { store.rename(note.id) }.buttonStyle(.borderless)
                            Button("Delete", role: .destructive) { store.delete(note.id) }.buttonStyle(.borderless)
                        }
                    }
                }
                if store.notes.isEmpty { Text("No records yet. Insert a synthetic note explicitly.") }
            }
        }
    }
}

private struct SwiftDataEditor: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PracticeNote.createdAt, order: .reverse) private var notes: [PracticeNote]
    @State private var title = "Synthetic note"
    @State private var status = "Explicit save after each action"
    private func save() {
        do { try context.save(); status = "SwiftData save succeeded" }
        catch { context.rollback(); status = "Save failed; rolled back: \(error.localizedDescription)" }
    }
    var body: some View {
        Form {
            Section("Model, container, context, query") {
                TextField("Title", text: $title)
                Button("Insert and save") { context.insert(PracticeNote(title: title)); save() }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text(status).font(.caption)
            }
            Section("Live @Query results") {
                ForEach(notes) { note in
                    VStack(alignment: .leading) {
                        Text(note.title)
                        Text(note.createdAt, format: .dateTime).font(.caption)
                        HStack {
                            Button("Rename") {
                                note.title = note.title.hasPrefix("Edited: ") ? String(note.title.dropFirst(8)) : "Edited: " + note.title
                                save()
                            }.buttonStyle(.borderless)
                            Button("Delete", role: .destructive) { context.delete(note); save() }.buttonStyle(.borderless)
                        }
                    }
                }
                if notes.isEmpty { Text("No records yet. This store is independent of Core Data.") }
            }
        }
    }
}
