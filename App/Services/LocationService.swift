import CoreLocation
import Foundation

/// Dünne Hülle um CLLocationManager. Liefert Standorte auch bei gesperrtem Bildschirm.
final class LocationService: NSObject, CLLocationManagerDelegate {

    var onLocation: ((CLLocation) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?

    private let manager = CLLocationManager()
    private var wantsUpdates = false
    private var isUpdating = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    var isAuthorized: Bool {
        let status = manager.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    /// Startet die Standortmessung und fragt bei Bedarf nach der Berechtigung.
    func start() {
        wantsUpdates = true
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if isAuthorized {
            beginUpdates()
        }
    }

    func stop() {
        wantsUpdates = false
        guard isUpdating else { return }
        isUpdating = false
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    private func beginUpdates() {
        guard !isUpdating else { return }
        isUpdating = true
        // Erfordert den Background Mode „location“ in der Info.plist.
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            onLocation?(location)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onAuthorizationChange?(manager.authorizationStatus)
        if wantsUpdates, isAuthorized {
            beginUpdates()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Vorübergehende Fehler (kein Empfang) meldet CoreLocation hier; die Messung läuft weiter.
    }
}
