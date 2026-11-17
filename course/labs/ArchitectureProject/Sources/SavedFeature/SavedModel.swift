import Observation
import NoteDomain

@MainActor @Observable
public final class SavedModel {
    public private(set) var notes: [Note] = []
    public private(set) var failed = false
    @ObservationIgnored private let repository: any NoteAccess
    @ObservationIgnored private var sessionRevision = 0
    @ObservationIgnored private var readRevision = 0
    public init(repository: any NoteAccess) { self.repository = repository }

    public func reload() async {
        readRevision += 1
        let ticket = readRevision
        let session = sessionRevision
        do {
            let result = try await repository.saved()
            try Task.checkCancellation()
            guard session == sessionRevision, ticket == readRevision else { return }
            notes = result; failed = false
        } catch {
            guard session == sessionRevision, ticket == readRevision else { return }
            notes = []; failed = !(error is CancellationError)
        }
    }

    public func toggle(id: String) async {
        let session = sessionRevision
        do {
            try await repository.toggleSaved(id: id)
            // Reads can overlap a mutation; only reset ends its session authority.
            guard session == sessionRevision else { return }
            await reload()
        } catch {
            guard session == sessionRevision else { return }
            failed = !(error is CancellationError)
        }
    }

    public func reset() {
        sessionRevision += 1; readRevision += 1
        notes = []; failed = false
    }
}
