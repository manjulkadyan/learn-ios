import Observation
import NoteDomain

public enum BrowseState: Equatable, Sendable {
    case idle, loading, ready([Note]), failed
}

@MainActor @Observable
public final class BrowseModel {
    public private(set) var state = BrowseState.idle
    @ObservationIgnored private let repository: any NoteAccess
    @ObservationIgnored private let clock: any ProjectClock
    @ObservationIgnored private var revision = 0

    public init(repository: any NoteAccess, clock: any ProjectClock) {
        self.repository = repository; self.clock = clock
    }

    // The caller owns the task. Revision guards both late success and late failure.
    public func refresh(_ freshness: Freshness = .reload, delay: Duration = .zero) async {
        revision += 1
        let ticket = revision
        state = .loading
        do {
            if delay > .zero { try await clock.sleep(for: delay) }
            let notes = try await repository.notes(freshness)
            try Task.checkCancellation()
            guard ticket == revision else { return }
            state = .ready(notes)
        } catch {
            guard ticket == revision else { return }
            if error is CancellationError || (error as? NoteFailure) == .expiredAccount || (error as? NoteFailure) == .staleRequest {
                state = .idle
            } else {
                state = .failed
            }
        }
    }

    public func reset() { revision += 1; state = .idle }
}
