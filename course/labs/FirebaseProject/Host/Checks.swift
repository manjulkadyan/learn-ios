import Foundation

@main
enum Checks {
    static func main() throws {
        var passed = 0
        func check(_ condition: Bool, _ label: String) {
            precondition(condition, label)
            passed += 1
            print("PASS: \(label)")
        }
        func fails(_ expected: PolicyFailure, _ label: String, _ action: () throws -> Void) {
            do { try action(); preconditionFailure(label) }
            catch { check((error as? PolicyFailure) == expected, label) }
        }
        _ = try LabEnvironment(projectID: "demo-firebase-course", host: "127.0.0.1")
        fails(.invalidEnvironment, "production project rejected") {
            _ = try LabEnvironment(projectID: "real-project", host: "127.0.0.1")
        }
        fails(.invalidEnvironment, "non-loopback endpoint rejected") {
            _ = try LabEnvironment(projectID: "demo-firebase-course", host: "example.com")
        }
        let initial = Note(id: "n1", ownerID: "alice", title: "Lantern", revision: 0)
        check(!NotePolicy.authorize(uid: nil, pathOwner: "alice", noteOwner: "alice"), "anonymous denied")
        check(!NotePolicy.authorize(uid: "bob", pathOwner: "alice", noteOwner: "alice"), "cross-account denied")
        check(!NotePolicy.authorize(uid: "alice", pathOwner: "alice", noteOwner: "bob"), "forged owner denied")
        let changed = try NotePolicy.revise(initial, uid: "alice", expected: 0, title: "  Paper boat  ")
        check(changed.title == "Paper boat" && changed.revision == 1, "validated edit increments revision")
        fails(.conflict, "stale edit preserves newer title") {
            _ = try NotePolicy.revise(changed, uid: "alice", expected: 0, title: "Old boat")
        }
        fails(.invalidTitle, "whitespace rejected") { _ = try NotePolicy.title(" \n ") }
        fails(.invalidTitle, "oversized title rejected") { _ = try NotePolicy.title(String(repeating: "a", count: 121)) }
        var session = SessionModel()
        session.switchAccount(to: "alice")
        let old = session.stamp!
        check(try session.accept([initial], from: old), "current snapshot accepted")
        session.switchAccount(to: "bob")
        check(session.rows.isEmpty, "account change clears visible rows")
        check(try !session.accept([initial], from: old), "late success rejected")
        session.switchAccount(to: "alice")
        check(try !session.accept([initial], from: old), "same-UID relogin rejects old generation")
        let current = session.stamp!
        fails(.malformedSnapshot, "foreign document rejected atomically") {
            _ = try session.accept([Note(id: "x", ownerID: "bob", title: "Private", revision: 0)], from: current)
        }
        let merged = try PagePolicy.merge([changed], [initial, changed], owner: "alice")
        check(merged == [changed], "overlap and older page cannot regress data")
        fails(.duplicatePayload, "same-revision disagreement exposed") {
            _ = try PagePolicy.merge([changed], [Note(id: "n1", ownerID: "alice", title: "Other", revision: 1)], owner: "alice")
        }
        var tokens = TokenOwnership()
        let a = TokenBinding(installation: "device1", uid: "alice", token: "t1")
        let b = TokenBinding(installation: "device1", uid: "bob", token: "t2")
        check(tokens.reconcile(uid: "alice", token: "t1", installation: "device1", optedIn: true) == [.attach(a)], "token binds current account")
        check(tokens.reconcile(uid: "alice", token: "t1", installation: "device1", optedIn: true).isEmpty, "duplicate token update has no effects")
        check(tokens.reconcile(uid: "bob", token: "t2", installation: "device1", optedIn: true) == [.detach(a), .attach(b)], "account and token rotation detach previous binding")
        check(tokens.reconcile(uid: nil, token: "t2", installation: "device1", optedIn: true) == [.detach(b)], "signout detaches token")
        check(!MediaPolicy.canUpload(uid: "bob", owner: "alice", bytes: 32, contentType: "image/jpeg"), "foreign upload denied")
        check(!MediaPolicy.canUpload(uid: "alice", owner: "alice", bytes: 1_048_577, contentType: "image/jpeg"), "oversized upload denied")
        check(!MediaPolicy.canUpload(uid: "alice", owner: "alice", bytes: 32, contentType: "text/plain"), "wrong MIME denied")
        check(MediaPolicy.canUpload(uid: "alice", owner: "alice", bytes: 1_048_576, contentType: "image/jpeg"), "inclusive upload boundary accepted")
        fails(.invalidID, "path traversal rejected") { _ = try MediaPolicy.path(owner: "alice", mediaID: "../bob") }
        check(MediaPolicy.recovery(uploaded: true, published: false, abandoned: true) == .removeOrphan, "abandoned upload needs cleanup")
        check(MediaPolicy.recovery(uploaded: true, published: false, abandoned: false) == .publishManifest, "manifest failure has recoverable next step")
        check(ConfigPolicy.pageSize(remote: 300) == 10 && ConfigPolicy.pageSize(remote: nil) == 10, "bad and absent config use bounded default")
        check(ConfigPolicy.readEstimate(sessions: 100, pageSize: 10, pages: 3) == 3000, "synthetic read arithmetic")
        check(ConfigPolicy.readEstimate(sessions: Int.max, pageSize: 25, pages: 3) == nil, "estimate overflow rejected")
        print("\(passed) offline policy checks passed; Firebase rules and SDK were not executed.")
    }
}
