#if FIREBASE_SDK_LAB
import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class FirebaseNotesRepository: ObservableObject {
    @Published private(set) var rows: [Note] = []
    @Published private(set) var status = "Not connected"
    @Published private(set) var pendingWrites = false
    private let database: Firestore
    private var listener: ListenerRegistration?
    private var session = SessionModel()

    init(database: Firestore) { self.database = database }

    // The composition owner must call disconnect before signout and on teardown.
    func disconnect() {
        listener?.remove()
        listener = nil
        session.switchAccount(to: nil)
        rows = []
        pendingWrites = false
        status = "Disconnected"
    }

    private func collection(uid: String) throws -> CollectionReference {
        guard NotePolicy.validID(uid) else { throw PolicyFailure.invalidID }
        return database.collection("users").document(uid).collection("notes")
    }

    nonisolated private static func decode(_ snapshot: DocumentSnapshot, owner: String) throws -> Note {
        guard let d = snapshot.data(), let uid = d["ownerID"] as? String,
              uid == owner, let title = d["title"] as? String,
              let revision = d["revision"] as? Int, revision >= 0,
              NotePolicy.validID(snapshot.documentID) else { throw PolicyFailure.malformedSnapshot }
        return Note(id: snapshot.documentID, ownerID: uid, title: title, revision: revision)
    }

    func connect(uid: String) throws {
        disconnect()
        session.switchAccount(to: uid)
        guard let stamp = session.stamp else { return }
        status = "Loading"
        // A bounded live first window. Historical pagination is a separate operation.
        listener = try collection(uid: uid).order(by: "updatedAt", descending: true)
            .limit(to: 10).addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self, self.session.stamp == stamp else { return }
                    if error != nil { self.status = "Listener failed; retry explicitly"; return }
                    guard let snapshot else { self.status = "Missing snapshot"; return }
                    do {
                        let notes = try snapshot.documents.map { try Self.decode($0, owner: uid) }
                        if try self.session.accept(notes, from: stamp) {
                            self.rows = self.session.rows
                            self.pendingWrites = snapshot.metadata.hasPendingWrites
                            self.status = snapshot.metadata.isFromCache ? "Cache result" : "Server result"
                        }
                    } catch { self.status = "Malformed note; preserve previous display" }
                }
            }
    }

    func create(uid: String, id: String, title raw: String) async throws {
        guard NotePolicy.validID(id) else { throw PolicyFailure.invalidID }
        let title = try NotePolicy.title(raw)
        let reference = try collection(uid: uid).document(id)
        // A transaction makes a retried create refuse replacement of an existing note.
        _ = try await database.runTransaction { transaction, pointer in
            do {
                guard try !transaction.getDocument(reference).exists else { throw PolicyFailure.conflict }
                transaction.setData(["ownerID": uid, "title": title, "revision": 0,
                                     "updatedAt": FieldValue.serverTimestamp()], forDocument: reference)
                return nil
            } catch { pointer?.pointee = error as NSError; return nil }
        }
    }

    func read(uid: String, id: String) async throws -> Note {
        guard NotePolicy.validID(id) else { throw PolicyFailure.invalidID }
        return try Self.decode(try await collection(uid: uid).document(id).getDocument(), owner: uid)
    }

    func revise(uid: String, id: String, expected: Int, title raw: String) async throws {
        guard NotePolicy.validID(id) else { throw PolicyFailure.invalidID }
        let title = try NotePolicy.title(raw)
        let reference = try collection(uid: uid).document(id)
        _ = try await database.runTransaction { transaction, pointer in
            do {
                let note = try Self.decode(transaction.getDocument(reference), owner: uid)
                let next = try NotePolicy.revise(note, uid: uid, expected: expected, title: title)
                transaction.updateData(["title": next.title, "revision": next.revision,
                                        "updatedAt": FieldValue.serverTimestamp()], forDocument: reference)
                return nil
            } catch { pointer?.pointee = error as NSError; return nil }
        }
    }

    func delete(uid: String, id: String) async throws {
        guard NotePolicy.validID(id) else { throw PolicyFailure.invalidID }
        try await collection(uid: uid).document(id).delete()
    }

    // Caller retains the actual last document, not a reconstructed title/time cursor.
    // This one-shot result must also be checked against caller account/request identity.
    func page(uid: String, after cursor: DocumentSnapshot?) async throws -> (notes: [Note], cursor: DocumentSnapshot?) {
        var query: Query = try collection(uid: uid).order(by: "updatedAt", descending: true)
            .limit(to: 10)
        if let cursor { query = query.start(afterDocument: cursor) }
        let snapshot = try await query.getDocuments()
        return (try snapshot.documents.map { try Self.decode($0, owner: uid) }, snapshot.documents.last)
    }
}
#else
#error("SDK source is separately gated; do not include in the offline Swift compile.")
#endif
