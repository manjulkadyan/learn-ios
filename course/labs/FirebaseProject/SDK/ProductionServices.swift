#if FIREBASE_PRODUCTION_SERVICES
// Optional integration source. Exclude from the emulator notebook target.
import Foundation
import UIKit
import UserNotifications
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
import FirebaseAnalytics
import FirebaseCrashlytics
import FirebasePerformance
import FirebaseRemoteConfig
import FirebaseAppCheck
import FirebaseFunctions
import FirebaseDatabase

final class AttestationFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        // This sample's deployment target is iOS 17; runtime support still needs device checks.
        AppAttestProvider(app: app)
    }
}

@MainActor
enum ProductionBootstrap {
    static func configureAfterEnvironmentReview() {
        // The learner supplies the reviewed target-specific GoogleService-Info.plist.
        // Initial collection defaults must be disabled in Info.plist BEFORE configure.
        AppCheck.setAppCheckProviderFactory(AttestationFactory())
        FirebaseApp.configure()
    }
    static func applyConsent(analytics: Bool, crashes: Bool, performance: Bool) {
        Analytics.setAnalyticsCollectionEnabled(analytics)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(crashes)
        Performance.sharedInstance().isDataCollectionEnabled = performance
    }
    static func traceSave<T>(_ operation: () async throws -> T) async rethrows -> T {
        let trace = Performance.startTrace(name: "notebook_save")
        defer { trace?.stop() }
        return try await operation()
    }
    static func pageSize() async throws -> Int {
        let config = RemoteConfig.remoteConfig()
        config.setDefaults(["notes_page_size": 10 as NSNumber])
        _ = try await config.fetchAndActivate()
        return ConfigPolicy.pageSize(remote: config["notes_page_size"].numberValue.intValue)
    }
    static func requestCleanup(mediaID: String, commandID: String) async throws {
        // Server implementation is separate; it must validate auth, rights and idempotency.
        _ = try await Functions.functions(region: "us-central1").httpsCallable("abandonMedia")
            .call(["mediaID": mediaID, "commandID": commandID])
    }
}

@MainActor
final class MessagingBridge: NSObject, UIApplicationDelegate, MessagingDelegate {
    // Send effects to an authenticated, idempotent server registry; this source sends none.
    var onToken: ((String) -> Void)?
    func installDelegates() { Messaging.messaging().delegate = self }
    func askAfterUserAction() async throws -> Bool {
        let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        if allowed { UIApplication.shared.registerForRemoteNotifications() }
        return allowed
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
        Messaging.messaging().apnsToken = token
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Present recoverable status without logging tokens or account content.
    }
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken token: String?) {
        guard let token else { return }
        Task { @MainActor [weak self] in self?.onToken?(token) }
    }
}

@MainActor
final class PresenceOwner {
    private let database: Database
    private var connectionHandle: DatabaseHandle?
    private var connectedReference: DatabaseReference?
    private var ownConnection: DatabaseReference?
    private var generation = 0
    init(database: Database) { self.database = database }
    func start(uid: String, installation: String) throws {
        guard NotePolicy.validID(uid), NotePolicy.validID(installation) else { throw PolicyFailure.invalidID }
        stop()
        let captured = generation
        let state = database.reference(withPath: "presence/\(uid)/\(installation)")
        ownConnection = state
        let connected = database.reference(withPath: ".info/connected")
        connectedReference = connected
        connectionHandle = connected.observe(.value) { [weak self] snapshot in
            guard snapshot.value as? Bool == true else { return }
            Task { @MainActor [weak self] in
                guard let self, self.generation == captured else { return }
                // Register server-side disconnect cleanup before advertising online.
                state.onDisconnectRemoveValue { [weak self] error, _ in
                    guard error == nil else { return }
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == captured else { return }
                        state.setValue(["online": true, "lastChanged": ServerValue.timestamp()])
                    }
                }
            }
        }
    }
    func stop() {
        generation += 1
        if let connectionHandle { connectedReference?.removeObserver(withHandle: connectionHandle) }
        ownConnection?.removeValue()
        connectedReference = nil
        connectionHandle = nil
        ownConnection = nil
        // Call before changing Auth credentials. Removal acknowledgement, disconnect
        // hook lifetime, reconnect races and device behavior still need integration tests.
    }
}
#else
#error("Optional remote services require FIREBASE_PRODUCTION_SERVICES and explicit separate target integration.")
#endif
