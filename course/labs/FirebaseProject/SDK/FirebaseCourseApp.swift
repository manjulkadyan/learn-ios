#if FIREBASE_SDK_LAB
import SwiftUI
import Combine
import FirebaseAuth

@MainActor
final class LabScreenModel: ObservableObject {
    @Published var message = "Start the local emulators separately, then connect."
    @Published var ready = false
    @Published private(set) var connected = false
    @Published private(set) var authBusy = false
    @Published private(set) var noteBusy = false
    @Published private(set) var pendingCreate: PendingCreate?
    private var services: FirebaseLabServices?
    @Published var notes: FirebaseNotesRepository?
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var active = false
    private var listenerGeneration = 0
    private var session = SessionModel()
    private var authWork = PublicationPolicy()
    private var noteWork = PublicationPolicy()

    func connect() {
        guard !active, !authBusy else { return }
        do {
            let created: FirebaseLabServices
            if let services { created = services }
            else { created = try FirebaseLabServices.make() }
            services = created
            if notes == nil { notes = FirebaseNotesRepository(database: created.database) }
            active = true
            connected = true
            installAuthListener()
            message = "Local services configured; choose a synthetic account."
        } catch { message = "Local configuration refused" }
    }
    private func removeAuthListener() {
        listenerGeneration += 1
        if let authHandle { services?.auth.removeStateDidChangeListener(authHandle) }
        authHandle = nil
    }
    private func installAuthListener() {
        removeAuthListener()
        guard let services else { return }
        let captured = listenerGeneration
        authHandle = services.auth.addStateDidChangeListener { [weak self] _, user in
            let uid = user?.uid
            Task { @MainActor [weak self] in
                guard let self, self.active, self.listenerGeneration == captured,
                      !self.authBusy, self.services?.auth.currentUser?.uid == uid else { return }
                self.applyAccount(uid)
            }
        }
    }
    private func clearAccount() {
        noteWork.invalidate()
        session.switchAccount(to: nil)
        notes?.disconnect()
        pendingCreate = nil
        noteBusy = false
        ready = false
    }
    private func applyAccount(_ uid: String?) {
        guard session.uid != uid else { return }
        clearAccount()
        guard let uid else { return }
        session.switchAccount(to: uid)
        do { try notes?.connect(uid: uid); ready = true }
        catch { message = "Unable to open account notes" }
    }
    func createSyntheticAccount() async {
        // Actor isolation plus this lock serializes all credential-changing submissions.
        guard active, !authBusy, let services else { return }
        authBusy = true
        authWork.invalidate()
        let captured = authWork.begin()
        clearAccount()
        installAuthListener()
        defer { authWork.finish(captured); authBusy = false }
        do {
            try Task.checkCancellation()
            let result = try await services.auth.createUser(withEmail: "\(UUID().uuidString)@example.invalid", password: "Local-only-example-42")
            guard active, authWork.accepts(captured), !Task.isCancelled else {
                // Auth can finish after teardown. Undo only this still-current synthetic login.
                if services.auth.currentUser?.uid == result.user.uid { try? services.auth.signOut() }
                return
            }
            guard services.auth.currentUser?.uid == result.user.uid else { return }
            applyAccount(result.user.uid)
            message = "Synthetic emulator account created"
        } catch {
            guard active, authWork.accepts(captured), !Task.isCancelled else { return }
            applyAccount(services.auth.currentUser?.uid)
            message = "Account creation failed; check local Auth emulator"
        }
    }
    func addNote() async {
        guard active, ready, !authBusy, !noteBusy, let services, let owner = session.stamp,
              services.auth.currentUser?.uid == owner.uid, let notes else { return }
        let retry = pendingCreate != nil
        if pendingCreate == nil {
            pendingCreate = PendingCreate(owner: owner, id: UUID().uuidString, title: "Paper lantern")
        }
        guard let draft = pendingCreate, draft.owner == owner else { return }
        let captured = noteWork.begin()
        noteBusy = true
        defer { if noteWork.finish(captured) { noteBusy = false } }
        do {
            try Task.checkCancellation()
            var decision = CreateReconciliation.create
            if retry {
                let record = try await notes.findOwnedOnServer(uid: owner.uid, id: draft.id)
                guard ownsNoteWork(captured, owner: owner) else { return }
                decision = CreatePolicy.reconcile(draft, serverNote: record)
            }
            switch decision {
            case .create: try await notes.create(uid: owner.uid, id: draft.id, title: draft.title)
            case .acknowledged: break
            case .conflict: throw PolicyFailure.conflict
            }
            guard ownsNoteWork(captured, owner: owner) else { return }
            pendingCreate = nil
            message = decision == .acknowledged ? "Original create confirmed at server" : "Create acknowledged"
        } catch {
            guard ownsNoteWork(captured, owner: owner) else { return }
            message = "Create unresolved; retain this ID and retry server reconciliation"
        }
    }
    private func ownsNoteWork(_ stamp: WorkStamp, owner: SessionStamp) -> Bool {
        active && !Task.isCancelled && noteWork.accepts(stamp) && session.stamp == owner
            && services?.auth.currentUser?.uid == owner.uid
    }
    func signOut() {
        guard active, !authBusy else { return }
        authBusy = true
        defer { authBusy = false }
        authWork.invalidate()
        removeAuthListener()
        clearAccount()
        do {
            try services?.auth.signOut()
            installAuthListener()
            message = "Signed out; display cleared"
        } catch { message = "Signout failed; display remains cleared; retry explicitly" }
    }
    func stop() {
        active = false
        connected = false
        authWork.invalidate()
        removeAuthListener()
        clearAccount()
    }
}

struct NotesPanel: View {
    @ObservedObject var repository: FirebaseNotesRepository
    var body: some View {
        Section(repository.status) {
            if repository.pendingWrites { Text("Local changes await acknowledgement") }
            ForEach(repository.rows, id: \.id) { note in
                VStack(alignment: .leading) {
                    Text(note.title)
                    Text("Revision \(note.revision)").font(.caption)
                }
            }
        }
    }
}

@main
struct FirebaseCourseApp: App {
    @StateObject private var model = LabScreenModel()
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List {
                    Text(model.message).accessibilityLabel("Connection status: \(model.message)")
                    Button("Connect local services") { model.connect() }
                    Button("Create synthetic local account") { Task { await model.createSyntheticAccount() } }
                        .disabled(!model.connected || model.authBusy)
                    Button(model.pendingCreate == nil ? "Add paper lantern note" : "Retry pending note") { Task { await model.addNote() } }
                        .disabled(!model.ready || model.authBusy || model.noteBusy)
                    Button("Sign out") { model.signOut() }.disabled(!model.connected || model.authBusy)
                    if let notes = model.notes { NotesPanel(repository: notes) }
                }
                .navigationTitle("Local notebook")
                .onDisappear { model.stop() }
            }
        }
    }
}
#else
#error("This app entry requires an isolated iOS target and FIREBASE_SDK_LAB.")
#endif
