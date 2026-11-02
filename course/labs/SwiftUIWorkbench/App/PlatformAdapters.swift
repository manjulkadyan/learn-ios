import SwiftUI
import Observation
import UserNotifications
import CoreLocation
import AVFoundation
import AuthenticationServices

@MainActor @Observable
final class NotificationAdapter: NSObject, UNUserNotificationCenterDelegate {
    var status = "Notification permission has not been requested by this app"
    @ObservationIgnored private let center = UNUserNotificationCenter.current()
    @ObservationIgnored private let router: WorkbenchRouter
    init(router: WorkbenchRouter, installDelegate: Bool) {
        self.router = router
        super.init()
        if installDelegate { center.delegate = self }
    }
    func requestPermission() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            status = granted ? "Permission granted" : "Permission denied; change it in Settings if desired"
        } catch { status = "Permission failed: \(error.localizedDescription)" }
    }
    func schedule() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            status = "Scheduling requires permission; use Request permission explicitly"
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Synthetic Alpha card"
        content.body = "Tap to open the local gallery fixture."
        content.userInfo = ["route": "workbench://gallery/item/alpha"]
        let request = UNNotificationRequest(identifier: "workbench.synthetic.alpha", content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false))
        do { try await center.add(request); status = "One synthetic notification scheduled for five seconds" }
        catch { status = "Scheduling failed: \(error.localizedDescription)" }
    }
    func clear() {
        center.removePendingNotificationRequests(withIdentifiers: ["workbench.synthetic.alpha"])
        center.removeDeliveredNotifications(withIdentifiers: ["workbench.synthetic.alpha"])
        status = "Removed this workshop's pending and delivered notification"
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let raw = response.notification.request.content.userInfo["route"] as? String
        Task { @MainActor [weak self] in
            if let raw, let url = URL(string: raw) { self?.router.open(url) }
            completionHandler()
        }
    }
}

@MainActor @Observable
final class LocationAdapter: NSObject, CLLocationManagerDelegate {
    var status = "Idle; no location request"
    @ObservationIgnored private var manager: CLLocationManager?
    @ObservationIgnored private var requestedFix = false
    func requestOneFix() {
        retireManager()
        guard CLLocationManager.locationServicesEnabled() else { status = "Location services unavailable"; return }
        let manager = CLLocationManager()
        self.manager = manager
        requestedFix = false
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        status = "Waiting for authorization or one fix"
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        else { continueAfterAuthorization(manager) }
    }
    private func continueAfterAuthorization(_ manager: CLLocationManager) {
        guard manager === self.manager else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if !requestedFix { requestedFix = true; manager.requestLocation() }
        case .denied: status = "Location denied; use Settings if desired"; retireManager()
        case .restricted: status = "Location restricted"; retireManager()
        case .notDetermined: break
        @unknown default: status = "Unknown location authorization"; retireManager()
        }
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in self?.continueAfterAuthorization(manager) }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let hasFix = !locations.isEmpty
        Task { @MainActor [weak self] in
            guard let self, manager === self.manager else { return }
            self.status = !hasFix ? "No fix returned" : "Fix available (\(manager.accuracyAuthorization == .fullAccuracy ? "full" : "reduced") accuracy); coordinates discarded"
            self.retireManager()
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let failure = error.localizedDescription
        Task { @MainActor [weak self] in
            guard let self, manager === self.manager else { return }
            self.status = "Location failed: \(failure)"
            self.retireManager()
        }
    }
    func cancel() { retireManager(); status = "Location request canceled" }
    private func retireManager() {
        manager?.stopUpdatingLocation()
        manager?.delegate = nil
        manager = nil
        requestedFix = false
    }
}

@MainActor @Observable
final class CameraAdapter {
    var status = "Idle; no camera permission requested"
    var presenting = false
    var image: UIImage?
    @ObservationIgnored private var generation = 0
    var captureTicket: Int { generation }
    func requestCapture() async {
        generation += 1
        let ticket = generation
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            status = "Camera unavailable (expected on Simulator)"
            return
        }
        let authorization = AVCaptureDevice.authorizationStatus(for: .video)
        if authorization == .restricted { status = "Camera restricted"; return }
        if authorization == .denied { status = "Camera denied; use Settings if desired"; return }
        status = "Waiting for camera permission"
        let allowed = authorization == .authorized ? true : await AVCaptureDevice.requestAccess(for: .video)
        guard ticket == generation, !Task.isCancelled else { return }
        guard allowed else { status = "Camera permission denied"; return }
        status = "Camera presented; capture or cancel"
        presenting = true
    }
    func completed(_ image: UIImage, ticket: Int) {
        guard ticket == generation, presenting else { return }
        generation += 1
        self.image = image
        status = "Captured in memory; not saved to Photos or disk"
        presenting = false
    }
    func cancel() {
        generation += 1
        presenting = false
        status = "Camera request canceled"
    }
    func canceledCapture(ticket: Int) {
        guard ticket == generation, presenting else { return }
        cancel()
    }
    func presentationEnded() {
        if status == "Camera presented; capture or cancel" { cancel() }
    }
    func clearImage() { image = nil }
}

struct CameraCapture: UIViewControllerRepresentable {
    let adapter: CameraAdapter
    func makeCoordinator() -> Coordinator { Coordinator(adapter) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    static func dismantleUIViewController(_ controller: UIImagePickerController, coordinator: Coordinator) { controller.delegate = nil }
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let adapter: CameraAdapter
        let ticket: Int
        init(_ adapter: CameraAdapter) { self.adapter = adapter; ticket = adapter.captureTicket }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { adapter.canceledCapture(ticket: ticket) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { adapter.completed(image, ticket: ticket) }
            else { adapter.canceledCapture(ticket: ticket) }
        }
    }
}

@MainActor @Observable
final class SystemAuthAdapter: NSObject, ASWebAuthenticationPresentationContextProviding {
    var status = "No provider configured. The demo never starts authentication automatically."
    var active = false
    @ObservationIgnored private var session: ASWebAuthenticationSession?
    @ObservationIgnored private weak var window: UIWindow?
    @ObservationIgnored private var generation = 0

    // A future caller must supply its own reviewed provider URL and OAuth state/PKCE validation.
    // The UI below deliberately does not invoke this method.
    func start(url: URL, callbackScheme: String, anchor: UIWindow) {
        guard url.scheme == "https", url.host != nil, url.user == nil, url.password == nil,
              !callbackScheme.isEmpty else { status = "Rejected invalid authentication configuration"; return }
        cancel()
        generation += 1
        let ticket = generation
        window = anchor
        let newSession = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { [weak self] callback, error in
            let canceled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
            Task { @MainActor [weak self] in
                guard let self, self.generation == ticket else { return }
                self.active = false
                self.session = nil
                self.window = nil
                self.status = canceled ? "Authentication canceled" :
                    (callback != nil && error == nil ? "Callback received; caller still must validate state/PKCE before trusting it" : "Authentication failed")
            }
        }
        newSession.presentationContextProvider = self
        newSession.prefersEphemeralWebBrowserSession = true
        session = newSession // Retain through completion or cancellation.
        active = newSession.start()
        status = active ? "System authentication running" : "System declined to start authentication"
        if !active { session = nil; window = nil }
    }
    func cancel() {
        generation += 1
        session?.cancel()
        session = nil
        window = nil
        active = false
        status = "Authentication canceled / no active session"
    }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // A session is only started with a supplied, scene-specific anchor.
        window ?? ASPresentationAnchor()
    }
}
