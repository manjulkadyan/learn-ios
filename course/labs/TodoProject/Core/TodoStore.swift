import Foundation

struct LoadedTodos {
    let items: [Todo]
    let needsMigrationSave: Bool
}

protocol TodoStoring {
    func load() throws -> LoadedTodos
    func save(_ items: [Todo]) throws
}

struct TodoEnvelope: Codable {
    let version: Int
    let items: [Todo]
}

private struct VersionHeader: Decodable { let version: Int }
private struct VersionOneEnvelope: Decodable {
    struct Item: Decodable { let id: UUID; let name: String; let done: Bool }
    let version: Int
    let tasks: [Item]
}

// Single owner, bounded teaching store. Atomic replacement is not multi-writer coordination.
final class FileTodoStore: TodoStoring {
    let url: URL
    init(url: URL) { self.url = url }

    func load() throws -> LoadedTodos {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return LoadedTodos(items: [], needsMigrationSave: false)
        }
        let decoder = JSONDecoder()
        let header = try decoder.decode(VersionHeader.self, from: data)
        let items: [Todo]
        let migrated: Bool
        switch header.version {
        case 1:
            let old = try decoder.decode(VersionOneEnvelope.self, from: data)
            items = try old.tasks.map { try Todo(id: $0.id, title: $0.name, isComplete: $0.done) }
            migrated = true
        case 2:
            items = try decoder.decode(TodoEnvelope.self, from: data).items
            migrated = false
        default: throw TodoError.unsupportedVersion(header.version)
        }
        try Todo.validate(items)
        return LoadedTodos(items: items, needsMigrationSave: migrated)
    }

    func save(_ items: [Todo]) throws {
        try Todo.validate(items)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let bytes = try encoder.encode(TodoEnvelope(version: 2, items: items))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: url, options: .atomic)
    }
}
