import Foundation
import CoreData

enum MigrationFailure: Error { case unsupported, failedPreservation }
func model(v2: Bool) -> NSManagedObjectModel {
    let model = NSManagedObjectModel()
    let entity = NSEntityDescription()
    entity.name = "Draft"
    entity.managedObjectClassName = "NSManagedObject"
    func text(_ name: String) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name; attribute.attributeType = .stringAttributeType
        attribute.isOptional = false
        return attribute
    }
    let title = text(v2 ? "displayTitle" : "title")
    if v2 { title.renamingIdentifier = "title" }
    entity.properties = [text("id"), text("account"), title]
    if v2 {
        let origin = text("origin")
        origin.defaultValue = "legacy"
        entity.properties.append(origin)
    }
    model.entities = [entity]
    return model
}
func open(_ url: URL, model: NSManagedObjectModel, readOnly: Bool = false) throws -> NSPersistentStoreCoordinator {
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
    try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil,
                                      at: url, options: [NSReadOnlyPersistentStoreOption: readOnly,
                                                        NSSQLitePragmasOption: ["journal_mode": "DELETE"]])
    return coordinator
}
func close(_ coordinator: NSPersistentStoreCoordinator) throws {
    for store in coordinator.persistentStores { try coordinator.remove(store) }
}
func rows(_ url: URL, v2: Bool) throws -> [String] {
    let coordinator = try open(url, model: model(v2: v2), readOnly: true)
    defer { try? close(coordinator) }
    let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    context.persistentStoreCoordinator = coordinator
    return try context.performAndWait {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Draft")
        return try context.fetch(request).map {
            let account = $0.value(forKey: "account") as! String
            let id = $0.value(forKey: "id") as! String
            let title = $0.value(forKey: v2 ? "displayTitle" : "title") as! String
            let origin = v2 ? $0.value(forKey: "origin") as! String : "legacy"
            return "\(account)|\(id)|\(title)|\(origin)"
        }.sorted()
    }
}
func migrate(source: URL, destination: URL, sourceModel: NSManagedObjectModel) throws {
    let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
        ofType: NSSQLiteStoreType, at: source, options: [NSReadOnlyPersistentStoreOption: true])
    guard sourceModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) else {
        throw MigrationFailure.unsupported
    }
    let target = model(v2: true)
    let mapping = try NSMappingModel.inferredMappingModel(forSourceModel: sourceModel, destinationModel: target)
    let manager = NSMigrationManager(sourceModel: sourceModel, destinationModel: target)
    try manager.migrateStore(from: source, sourceType: NSSQLiteStoreType,
                             options: [NSReadOnlyPersistentStoreOption: true], with: mapping,
                             toDestinationURL: destination, destinationType: NSSQLiteStoreType,
                             destinationOptions: [NSSQLitePragmasOption: ["journal_mode": "DELETE"]])
    guard try rows(source, v2: false) == rows(destination, v2: true) else {
        throw MigrationFailure.failedPreservation
    }
}
@main struct CoreDataMigrationCheck {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else { fatalError("Pass an isolated temp directory") }
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("v1.sqlite")
        let destination = root.appendingPathComponent("v2.sqlite")
        let coordinator = try open(source, model: model(v2: false))
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try context.performAndWait {
            for account in ["A", "B"] {
                let draft = NSEntityDescription.insertNewObject(forEntityName: "Draft", into: context)
                draft.setValue("same-id", forKey: "id")
                draft.setValue(account, forKey: "account")
                draft.setValue("\(account) old title", forKey: "title")
            }
            try context.save()
            context.reset()
        }
        try close(coordinator)
        let before = try Data(contentsOf: source)
        try migrate(source: source, destination: destination, sourceModel: model(v2: false))
        guard try rows(destination, v2: true) == ["A|same-id|A old title|legacy", "B|same-id|B old title|legacy"]
        else { throw MigrationFailure.failedPreservation }
        // Recognizable SQLite store, deliberately unsupported source model.
        do {
            try migrate(source: source, destination: root.appendingPathComponent("unsupported.sqlite"),
                        sourceModel: model(v2: true))
            throw MigrationFailure.failedPreservation
        } catch MigrationFailure.unsupported {}
        // A file where the destination's parent directory should be: deterministic I/O failure.
        let blocker = root.appendingPathComponent("not-a-directory")
        try Data("block".utf8).write(to: blocker)
        do {
            try migrate(source: source, destination: blocker.appendingPathComponent("failed.sqlite"),
                        sourceModel: model(v2: false))
            throw MigrationFailure.failedPreservation
        } catch MigrationFailure.failedPreservation { throw MigrationFailure.failedPreservation }
          catch { /* Expected destination failure; preservation checked below. */ }
        let corrupt = root.appendingPathComponent("corrupt.sqlite")
        let bytes = Data("not a sqlite store".utf8)
        try bytes.write(to: corrupt)
        do {
            try migrate(source: corrupt, destination: root.appendingPathComponent("corrupt-target.sqlite"),
                        sourceModel: model(v2: false))
            throw MigrationFailure.failedPreservation
        } catch MigrationFailure.failedPreservation { throw MigrationFailure.failedPreservation }
          catch { /* Framework metadata failure expected. */ }
        guard try Data(contentsOf: source) == before, try Data(contentsOf: corrupt) == bytes,
              try rows(source, v2: false).count == 2 else { throw MigrationFailure.failedPreservation }
        print("PASS Core Data: V1 SQLite -> inferred mapping -> distinct V2 SQLite; rename/default/A-B preserved;")
        print("unsupported model, corrupt source and destination I/O failure retain original bytes")
    }
}
