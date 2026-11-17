import Observation
import NoteDomain

@MainActor @Observable
public final class SavedModel {
    public private(set) var notes: [Note] = []
    public private(set) var failed = false
    @ObservationIgnored private let repository: any NoteAccess
    @ObservationIgnored private var revision = 0
    public init(repository: any NoteAccess) { self.repository = repository }

    public func reload() async {
        revision += 1
        let ticket = revision
        do {
            let result = try await repository.saved()
            try Task.checkCancellation()
            guard ticket == revision else { return }
            notes = result; failed = false
        } catch {
            guard ticket == revision else { return }
            notes = []; failed = !(error is CancellationError)
        }
    }

    public func toggle(id: String) async {
        let ticket = revision
        do {
            try await repository.toggleSaved(id: id)
            guard ticket == revision else { return }
            await reload()
        } catch {
            guard ticket == revision else { return }
            failed = !(error is CancellationError)
        }
    }

    public func reset() { revision += 1; notes = []; failed = false }
}
