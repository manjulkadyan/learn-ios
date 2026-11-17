#if FIREBASE_SDK_LAB
import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

// Emulator-only bootstrap. Optional production services belong to a different target.
@MainActor
struct FirebaseLabServices {
    let auth: Auth
    let database: Firestore
    let storage: Storage

    static func make() throws -> FirebaseLabServices {
        let environment = try LabEnvironment(projectID: "demo-firebase-course", host: "127.0.0.1")
        let options = FirebaseOptions(googleAppID: "1:1234567890:ios:0123456789abcdef", gcmSenderID: "1234567890")
        options.projectID = environment.projectID
        options.apiKey = "fake-api-key-for-local-emulator-only"
        options.bundleID = Bundle.main.bundleIdentifier
        options.storageBucket = "demo-firebase-course.appspot.com"
        let name = "FirebaseCourseEmulator"
        if FirebaseApp.app(name: name) == nil { FirebaseApp.configure(name: name, options: options) }
        guard let app = FirebaseApp.app(name: name) else { throw PolicyFailure.invalidEnvironment }
        let auth = Auth.auth(app: app)
        auth.useEmulator(withHost: environment.host, port: 9099)
        let database = Firestore.firestore(app: app)
        let settings = database.settings
        settings.host = "\(environment.host):8080"
        settings.isSSLEnabled = false
        settings.cacheSettings = MemoryCacheSettings()
        database.settings = settings
        let storage = Storage.storage(app: app)
        storage.useEmulator(withHost: environment.host, port: 9199)
        return FirebaseLabServices(auth: auth, database: database, storage: storage)
    }
}
#else
#error("Exclude SDK files from the host build. An isolated iOS target requires FIREBASE_SDK_LAB and provisioned Firebase products.")
#endif
