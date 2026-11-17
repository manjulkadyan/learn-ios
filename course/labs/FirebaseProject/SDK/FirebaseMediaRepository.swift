#if FIREBASE_SDK_LAB
import Foundation
import FirebaseStorage

@MainActor
final class FirebaseMediaRepository {
    private let storage: Storage
    private var task: StorageUploadTask?
    init(storage: Storage) { self.storage = storage }

    // This method accepts already prepared JPEG bytes, never raw picker assets.
    // Only one active transfer belongs to this owner; a replacement cancels it.
    func upload(uid: String, mediaID: String, jpeg: Data,
                completion: @escaping (Result<MediaUploadReceipt, Error>) -> Void) throws {
        guard MediaPolicy.canUpload(uid: uid, owner: uid, bytes: jpeg.count, contentType: "image/jpeg") else {
            throw PolicyFailure.invalidTitle
        }
        let path = try MediaPolicy.path(owner: uid, mediaID: mediaID)
        task?.cancel()
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = ["ownerID": uid]
        task = storage.reference(withPath: path).putData(jpeg, metadata: metadata) { uploaded, error in
            // Caller checks account generation before showing this completion.
            if let error { completion(.failure(error)) }
            else if let uploaded, uploaded.generation > 0 {
                completion(.success(MediaUploadReceipt(path: path, generation: String(uploaded.generation))))
            } else { completion(.failure(PolicyFailure.malformedSnapshot)) }
        }
    }
    func cancel() { task?.cancel(); task = nil }
    func download(uid: String, mediaID: String) async throws -> Data {
        let path = try MediaPolicy.path(owner: uid, mediaID: mediaID)
        return try await storage.reference(withPath: path).data(maxSize: 1_048_576)
    }
    func remove(uid: String, mediaID: String) async throws {
        let path = try MediaPolicy.path(owner: uid, mediaID: mediaID)
        try await storage.reference(withPath: path).delete()
    }
}
#else
#error("SDK source is separately gated; do not include in the offline Swift compile.")
#endif
