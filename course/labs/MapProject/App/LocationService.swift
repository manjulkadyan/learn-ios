import Foundation
import CoreLocation
import Combine

// CLLocationManager is created on the main actor. Its delegate callbacks use
// that run loop. The preconcurrency conformance handles the older delegate contract.
@MainActor
final class LocationService: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var message = "Simulation origin is active."
    @Published private(set) var coordinate: Coordinate?
    @Published private(set) var accuracy: CLLocationAccuracy?
    private let manager = CLLocationManager()
    private var wantsFix = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // No permission request and no requestLocation in init.
    }

    func requestFromButton() {
        wantsFix = true
        switch manager.authorizationStatus {
        case .notDetermined:
            message = "Waiting for the person's permission choice."
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            message = "Requesting one location fix."
            manager.requestLocation()
        case .denied:
            wantsFix = false
            message = "Location denied. Use the simulation origin or change Settings."
        case .restricted:
            wantsFix = false
            message = "Location restricted. Use the simulation origin."
        @unknown default:
            wantsFix = false
            message = "Unknown authorization state. Use the simulation origin."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // An initial delegate callback is NOT permission to request a location.
        guard wantsFix else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            message = manager.accuracyAuthorization == .reducedAccuracy
                ? "Approximate location allowed; requesting one fix."
                : "Location allowed; requesting one fix."
            manager.requestLocation()
        case .denied, .restricted:
            wantsFix = false
            message = "Location unavailable by permission. Simulation still works."
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard wantsFix else { return }
        wantsFix = false
        guard let fix = locations.last, fix.horizontalAccuracy >= 0,
              abs(fix.timestamp.timeIntervalSinceNow) <= 60,
              let point = try? Coordinate(latitude: fix.coordinate.latitude,
                                         longitude: fix.coordinate.longitude) else {
            message = "No recent usable fix. Keep the simulation origin."
            return
        }
        coordinate = point
        accuracy = fix.horizontalAccuracy
        message = "One fix received; accuracy about \(Int(fix.horizontalAccuracy)) metres."
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard wantsFix else { return }
        wantsFix = false
        message = "Location fix failed. Retry explicitly or use simulation."
    }

    func stop() {
        wantsFix = false
        manager.stopUpdatingLocation()
    }
}

