import CoreLocation
import Observation

// MARK: - Location provider
//
// A thin wrapper over CLLocationManager that publishes the latest coordinate and
// authorization status for the map. Used only to show the blue user dot and to
// re-center the camera — coarse accuracy is plenty and keeps it light.

@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    /// Latest known coordinate, or nil until the first fix arrives.
    var coordinate: CLLocationCoordinate2D?
    /// Current authorization, kept in sync with the system.
    var authorization: CLAuthorizationStatus

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Ask for when-in-use access (no-op if already decided) and begin updates
    /// once authorized.
    func start() {
        switch authorization {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if isAuthorized { manager.startUpdatingLocation() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let last = locations.last { coordinate = last.coordinate }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Non-fatal: keep the last known coordinate (if any).
    }
}
