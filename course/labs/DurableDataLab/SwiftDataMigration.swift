import Foundation
import SwiftData

// Requires macOS 14+ / iOS 17+ and macro-capable tooling. A real SQLite-backed store.
enum V1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Draft.self] }
    @Model final class Draft {
        var id: String
        var account: String
        var title: String
        init(id: String, account: String, title: String) {
            self.id = id; self.account = account; self.title = title
        }
    }
}
enum V2: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(2, 0, 0) }
    static var models: [any PersistentModel.Type] { [Draft.self] }
    @Model final class Draft {
        var id: String
        var account: String
        @Attribute(originalName: "title") var displayTitle: String
        var origin: String = "legacy"
        init(id: String, account: String, displayTitle: String) {
            self.id = id; self.account = account; self.displayTitle = displayTitle
        }
    }
}
enum Plan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [V1.self, V2.self] }
    static var stages: [MigrationStage] { [.lightweight(fromVersion: V1.self, toVersion: V2.self)] }
}
@main struct SwiftDataMigrationCheck {
    @MainActor static func main() throws {
        guard CommandLine.arguments.count == 2 else { fatalError("Pass an isolated store URL") }
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try autoreleasepool {
            let schema = Schema(versionedSchema: V1.self)
            let old = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            let context = ModelContext(old)
            context.autosaveEnabled = false
            context.insert(V1.Draft(id: "same-id", account: "A", title: "A old title"))
            context.insert(V1.Draft(id: "same-id", account: "B", title: "B old title"))
            try context.save()
        }
        try autoreleasepool {
            let schema = Schema(versionedSchema: V2.self)
            let upgraded = try ModelContainer(for: schema, migrationPlan: Plan.self,
                                             configurations: [ModelConfiguration(schema: schema, url: url)])
            let context = ModelContext(upgraded)
            let actual = try context.fetch(FetchDescriptor<V2.Draft>()).map {
                "\($0.account)|\($0.id)|\($0.displayTitle)|\($0.origin)"
            }.sorted()
            guard actual == ["A|same-id|A old title|legacy", "B|same-id|B old title|legacy"] else {
                throw NSError(domain: "SwiftDataPreservation", code: 1)
            }
        }
        print("PASS SwiftData: actual disk V1 -> V2 migration plan, renamed title, default, account identities")
    }
}
