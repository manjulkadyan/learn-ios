import Foundation

// Offline teaching contracts. This is not the Firebase Security Rules engine.
enum PolicyFailure: Error, Equatable {
    case invalidEnvironment, invalidID, invalidTitle, unauthorized, conflict
    case duplicatePayload, malformedSnapshot
}

struct LabEnvironment: Equatable {
    let projectID: String
    let host: String
    init(projectID: String, host: String) throws {
        guard projectID == "demo-firebase-course", host == "127.0.0.1" else {
            throw PolicyFailure.invalidEnvironment
        }
        self.projectID = projectID
        self.host = host
    }
}

struct Note: Equatable, Sendable {
    let id: String
    let ownerID: String
    var title: String
    var revision: Int
}

enum NotePolicy {
    static func validID(_ id: String) -> Bool {
        !id.isEmpty && id.utf8.count <= 64 && id.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0)
                || (97...122).contains($0) || $0 == 45 || $0 == 95
        }
    }
    static func title(_ raw: String) throws -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 120 else { throw PolicyFailure.invalidTitle }
        return value
    }
    static func authorize(uid: String?, pathOwner: String, noteOwner: String) -> Bool {
        uid != nil && uid == pathOwner && noteOwner == pathOwner
    }
    static func revise(_ note: Note, uid: String?, expected: Int, title raw: String) throws -> Note {
        guard authorize(uid: uid, pathOwner: note.ownerID, noteOwner: note.ownerID) else {
            throw PolicyFailure.unauthorized
        }
        guard expected == note.revision, expected >= 0, expected < Int.max else {
            throw PolicyFailure.conflict
        }
        var next = note
        next.title = try title(raw)
        next.revision += 1
        return next
    }
}

struct SessionStamp: Equatable, Sendable {
    let uid: String
    let generation: Int
}

struct SessionModel {
    private(set) var uid: String?
    private(set) var generation = 0
    private(set) var rows: [Note] = []
    mutating func switchAccount(to next: String?) {
        generation += 1
        uid = next
        rows = []
    }
    var stamp: SessionStamp? {
        uid.map { SessionStamp(uid: $0, generation: generation) }
    }
    // Reject callbacks from a previous login, even if the same UID returns later.
    mutating func accept(_ incoming: [Note], from stamp: SessionStamp) throws -> Bool {
        guard self.stamp == stamp else { return false }
        guard incoming.allSatisfy({ $0.ownerID == stamp.uid && NotePolicy.validID($0.id) }),
              Set(incoming.map(\.id)).count == incoming.count else {
            throw PolicyFailure.malformedSnapshot
        }
        rows = incoming
        return true
    }
}

enum PagePolicy {
    // Pages are a frozen browsing example, not a simulation of Firestore ordering.
    static func merge(_ existing: [Note], _ page: [Note], owner: String) throws -> [Note] {
        var byID: [String: Note] = [:]
        var order: [String] = []
        for note in existing + page {
            guard note.ownerID == owner, NotePolicy.validID(note.id), note.revision >= 0 else {
                throw PolicyFailure.malformedSnapshot
            }
            if let old = byID[note.id] {
                if note.revision < old.revision { continue }
                if note.revision == old.revision && note != old {
                    throw PolicyFailure.duplicatePayload
                }
            } else { order.append(note.id) }
            byID[note.id] = note
        }
        return order.compactMap { byID[$0] }
    }
}

struct TokenBinding: Equatable {
    let installation: String
    let uid: String
    let token: String
}
enum TokenEffect: Equatable {
    case detach(TokenBinding), attach(TokenBinding)
}
struct TokenOwnership {
    private(set) var binding: TokenBinding?
    mutating func reconcile(uid: String?, token: String?, installation: String,
                            optedIn: Bool) -> [TokenEffect] {
        let desired: TokenBinding? = optedIn ? uid.flatMap { user in
            token.flatMap { $0.isEmpty ? nil : TokenBinding(installation: installation, uid: user, token: $0) }
        } : nil
        guard desired != binding else { return [] }
        var effects: [TokenEffect] = []
        if let old = binding { effects.append(.detach(old)) }
        if let desired { effects.append(.attach(desired)) }
        binding = desired
        return effects
    }
}

enum MediaRecovery: Equatable { case upload, publishManifest, complete, removeOrphan }
struct MediaPolicy {
    static func path(owner: String, mediaID: String) throws -> String {
        guard NotePolicy.validID(owner), NotePolicy.validID(mediaID) else {
            throw PolicyFailure.invalidID
        }
        return "users/\(owner)/media/\(mediaID).jpg"
    }
    static func canUpload(uid: String?, owner: String, bytes: Int, contentType: String) -> Bool {
        uid == owner && uid != nil && bytes > 0 && bytes <= 1_048_576 && contentType == "image/jpeg"
    }
    static func recovery(uploaded: Bool, published: Bool, abandoned: Bool) -> MediaRecovery {
        if published { return .complete }
        if uploaded { return abandoned ? .removeOrphan : .publishManifest }
        return .upload
    }
}

struct ConfigPolicy {
    static func pageSize(remote: Int?) -> Int {
        guard let remote, (1...25).contains(remote) else { return 10 }
        return remote
    }
    // Synthetic arithmetic only; no real Firebase price or quota is asserted.
    static func readEstimate(sessions: Int, pageSize: Int, pages: Int) -> Int? {
        guard sessions >= 0, (1...25).contains(pageSize), pages >= 0 else { return nil }
        let first = sessions.multipliedReportingOverflow(by: pageSize)
        let second = first.partialValue.multipliedReportingOverflow(by: pages)
        return first.overflow || second.overflow ? nil : second.partialValue
    }
}
