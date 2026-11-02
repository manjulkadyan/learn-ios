import Foundation
import CoreData

@main struct NativeChecks {
    @MainActor static func main() throws {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "Draft"; entity.managedObjectClassName = "NSManagedObject"
        entity.properties = ["id", "account", "displayTitle", "origin"].map {
            let attribute = NSAttributeDescription()
            attribute.name = $0; attribute.attributeType = .stringAttributeType
            attribute.isOptional = false
            return attribute
        }
        model.entities = [entity]
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        let owner = try NativeTransactionOwner(context: context)
        let oldA = owner.activate("A")
        try owner.replace([DraftSnapshot(id: "same", title: "old A")], account: "A", epoch: oldA)
        let b = owner.activate("B")
        try owner.replace([DraftSnapshot(id: "same", title: "keep B")], account: "B", epoch: b)
        let newA = owner.activate("A")
        do {
            try owner.replace([DraftSnapshot(id: "same", title: "stale")], account: "A", epoch: oldA)
            throw NSError(domain: "ExpectedStaleNativeCommit", code: 1)
        } catch NativeCommitFailure.stale {}
        try owner.replace([DraftSnapshot(id: "same", title: "new A")], account: "A", epoch: newA)
        let reader = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        reader.persistentStoreCoordinator = coordinator
        let values = try reader.performAndWait {
            try reader.fetch(NSFetchRequest<NSManagedObject>(entityName: "Draft")).map {
                "\($0.value(forKey: "account") as! String)|\($0.value(forKey: "displayTitle") as! String)"
            }.sorted()
        }
        guard values == ["A|new A", "B|keep B"] else { throw NSError(domain: "NativeIsolation", code: 1) }
        do {
            _ = try NativeTransactionOwner(context: reader)
            throw NSError(domain: "ExpectedWrongContext", code: 1)
        } catch NativeCommitFailure.wrongContext {}
        print("PASS native owner: main-queue/actor bridge, fresh-context read, A-B-A stale rejection, B preservation")
        print("In-memory macOS check only; not an iOS protected-file or process-restart check")
    }
}
