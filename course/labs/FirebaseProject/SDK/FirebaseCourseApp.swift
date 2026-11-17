#if FIREBASE_SDK_LAB
import SwiftUI
import Combine
import FirebaseAuth

@MainActor
final class LabScreenModel: ObservableObject {
    @Published var message = "Start the local emulators separately, then connect."
    @Published var ready = false
    private var services: FirebaseLabServices?
    @Published var notes: FirebaseNotesRepository?
    private var authHandle: AuthStateDidChangeListenerHandle?

    func connect() {
        guard services == nil else { return }
        do {
            let created = try FirebaseLabServices.make()
            services = created
            let repository = FirebaseNotesRepository(database: created.database)
            notes = repository
            authHandle = created.auth.addStateDidChangeListener { [weak self] _, user in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.notes?.disconnect()
                    self.ready = user != nil
                    do { if let user { try self.notes?.connect(uid: user.uid) } }
                    catch { self.message = "Unable to open account notes" }
                }
            }
            message = "Local services configured; choose a synthetic account."
        } catch { message = "Local configuration refused" }
    }
    func createSyntheticAccount() async {
        guard let services else { return }
        do {
            _ = try await services.auth.createUser(withEmail: "\(UUID().uuidString)@example.invalid", password: "Local-only-example-42")
            message = "Synthetic emulator account created"
        } catch { message = "Account creation failed; check local Auth emulator" }
    }
    func addNote() async {
        guard let services, let uid = services.auth.currentUser?.uid, let notes else { return }
        do {
            try await notes.create(uid: uid, id: UUID().uuidString, title: "Paper lantern")
            message = "Create acknowledged"
        } catch { message = "Create failed; preserve the draft and retry explicitly" }
    }
    func signOut() {
        notes?.disconnect()
        ready = false
        do { try services?.auth.signOut(); message = "Signed out; display cleared" }
        catch { message = "Signout failed; display remains cleared" }
    }
    func stop() {
        notes?.disconnect()
        if let authHandle { services?.auth.removeStateDidChangeListener(authHandle) }
        authHandle = nil
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
                    Button("Add paper lantern note") { Task { await model.addNote() } }.disabled(!model.ready)
                    Button("Sign out") { model.signOut() }.disabled(!model.ready)
                    if let notes = model.notes { NotesPanel(repository: notes) }
                }
                .navigationTitle("Local notebook")
            }
        }
    }
}
#else
#error("This app entry requires an isolated iOS target and FIREBASE_SDK_LAB.")
#endif
