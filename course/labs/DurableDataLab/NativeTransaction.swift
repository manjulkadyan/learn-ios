import Foundation
import CoreData

struct DraftSnapshot: Sendable { let id: String; let title: String }
enum NativeCommitFailure: Error { case stale, wrongContext }
// Target-required: owns a dedicated main-queue writer for the lab's V2 Draft model.
// No UI editor may share this context; rollback/reset applies to the whole context.
@MainActor final class NativeTransactionOwner {
    private let context: NSManagedObjectContext
    private var epoch = UUID()
    private var account: String?
    init(context: NSManagedObjectContext) throws {
        guard context.concurrencyType == .mainQueueConcurrencyType else { throw NativeCommitFailure.wrongContext }
        self.context = context
    }
    func activate(_ account: String) -> UUID {
        context.reset()
        self.account = account
        epoch = UUID()
        return epoch
    }
    func replace(_ drafts: [DraftSnapshot], account capturedAccount: String, epoch capturedEpoch: UUID) throws {
        try context.performAndWait {
            // The constructor enforces a main-queue context and the caller is
            // MainActor-isolated. Assert that bridge inside Core Data's Sendable
            // closure instead of accessing actor state through an unchecked hop.
            try MainActor.assumeIsolated {
            try Task.checkCancellation()
            guard account == capturedAccount, epoch == capturedEpoch else { throw NativeCommitFailure.stale }
            do {
                let request = NSFetchRequest<NSManagedObject>(entityName: "Draft")
                request.predicate = NSPredicate(format: "account == %@", capturedAccount)
                for object in try context.fetch(request) { context.delete(object) }
                for value in drafts {
                    let object = NSEntityDescription.insertNewObject(forEntityName: "Draft", into: context)
                    object.setValue(value.id, forKey: "id")
                    object.setValue(capturedAccount, forKey: "account")
                    object.setValue(value.title, forKey: "displayTitle")
                    object.setValue("lab", forKey: "origin")
                }
                try context.save()
            } catch {
                context.rollback()
                throw error
            }
            }
        }
    }
}
