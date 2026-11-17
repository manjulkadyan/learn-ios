import Foundation
import Observation
import NoteDomain
import NoteData
import BrowseFeature
import SavedFeature

public enum Route: Hashable, Sendable { case detail(session: UUID, account: String, id: String) }
public enum NoteTab: Hashable { case browse, saved }

@MainActor @Observable
public final class Shell {
    public private(set) var account: String
    public private(set) var sessionID = UUID()
    public var path: [Route] = []
    public var tab = NoteTab.browse
    public private(set) var browse: BrowseModel
    public private(set) var saved: SavedModel
    @ObservationIgnored private var repository: NoteRepository
    @ObservationIgnored private let reader: any NoteReading
    @ObservationIgnored private let clock: any ProjectClock
    @ObservationIgnored private var browseTask: Task<Void, Never>?
    public private(set) var switching = false

    public init(account: String = "demo-a", reader: any NoteReading = SyntheticReader(), clock: any ProjectClock = LiveClock()) {
        self.account = account; self.reader = reader; self.clock = clock
        let repository = NoteRepository(account: account, reader: reader, clock: clock)
        self.repository = repository
        browse = BrowseModel(repository: repository, clock: clock)
        saved = SavedModel(repository: repository)
    }

    public func refresh() {
        guard !switching else { return }
        browseTask?.cancel()
        let model = browse
        browseTask = Task { await model.refresh() }
    }

    public func waitForRefresh() async { await browseTask?.value }

    public func switchAccount(to next: String) async {
        guard !switching else { return }
        switching = true
        browseTask?.cancel(); browseTask = nil
        browse.reset(); saved.reset(); path = []; tab = .browse
        // Revoke repository commit authority before publishing the next session.
        await repository.invalidate()
        account = next; sessionID = UUID()
        let nextRepository = NoteRepository(account: next, reader: reader, clock: clock)
        repository = nextRepository
        browse = BrowseModel(repository: nextRepository, clock: clock)
        saved = SavedModel(repository: nextRepository)
        switching = false
    }

    public func open(id: String) { path.append(.detail(session: sessionID, account: account, id: id)) }

    public func resolve(_ route: Route) async throws -> Note {
        let session = sessionID
        guard case let .detail(routeSession, owner, id) = route, routeSession == session, owner == account, !switching else {
            throw NoteFailure.expiredAccount
        }
        let result = try await repository.detail(id: id)
        guard session == sessionID, !switching else { throw NoteFailure.expiredAccount }
        return result
    }

    public func toggleSaved(_ route: Route) async {
        guard case let .detail(routeSession, owner, id) = route, routeSession == sessionID, owner == account, !switching else { return }
        let model = saved
        await model.toggle(id: id)
    }

    public func stop() { browseTask?.cancel(); browseTask = nil; browse.reset() }
}
