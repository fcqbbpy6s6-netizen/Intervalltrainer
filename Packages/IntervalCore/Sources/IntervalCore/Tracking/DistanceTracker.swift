import Foundation

/// Ein GPS-Messpunkt, unabhängig von CoreLocation.
public struct LocationSample: Equatable, Sendable {
    /// Zeitstempel in Sekunden (beliebiger, aber fester Nullpunkt).
    public var timestamp: TimeInterval
    public var latitude: Double
    public var longitude: Double
    /// Horizontale Genauigkeit in Metern, negativ = ungültig.
    public var horizontalAccuracy: Double

    public init(timestamp: TimeInterval, latitude: Double, longitude: Double, horizontalAccuracy: Double) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
    }
}

public enum Geo {
    /// Entfernung zweier Punkte in Metern (Haversine).
    public static func distance(_ a: LocationSample, _ b: LocationSample) -> Double {
        let radius = 6_371_000.0
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * radius * asin(min(1, sqrt(h)))
    }
}

public struct DistanceTrackerConfig: Equatable, Sendable {
    /// Punkte mit schlechterer Genauigkeit werden verworfen.
    public var maxHorizontalAccuracy: Double = 25
    /// Sprünge mit höherer Geschwindigkeit (m/s) gelten als Ausreißer.
    public var maxSpeed: Double = 12
    /// Bewegungen unterhalb dieser Strecke (Meter) gelten als Rauschen.
    public var minStep: Double = 2
    /// Anteil der Genauigkeit, der zusätzlich als Rauschschwelle dient.
    public var accuracyStepFactor: Double = 0.25
    /// Nach so vielen Ausreißern in Folge wird neu aufgesetzt.
    public var maxConsecutiveOutliers = 5

    public init() {}
}

/// Summiert die gelaufene Strecke aus GPS-Punkten und filtert Ungenaues und Ausreißer.
public struct DistanceTracker: Sendable {
    public var config: DistanceTrackerConfig
    public private(set) var totalDistance: Double = 0
    public private(set) var anchor: LocationSample?
    private var outliersInRow = 0

    public init(config: DistanceTrackerConfig = DistanceTrackerConfig()) {
        self.config = config
    }

    public mutating func reset() {
        totalDistance = 0
        anchor = nil
        outliersInRow = 0
    }

    /// Nimmt einen Messpunkt auf.
    /// - Returns: true, wenn der Punkt brauchbar war (auch ohne Streckenzuwachs).
    @discardableResult
    public mutating func add(_ sample: LocationSample) -> Bool {
        guard sample.horizontalAccuracy >= 0, sample.horizontalAccuracy <= config.maxHorizontalAccuracy else {
            return false
        }
        guard let last = anchor else {
            anchor = sample
            return true
        }
        let deltaTime = sample.timestamp - last.timestamp
        guard deltaTime > 0 else { return false }

        let step = Geo.distance(last, sample)
        if step / deltaTime > config.maxSpeed {
            outliersInRow += 1
            if outliersInRow >= config.maxConsecutiveOutliers {
                // Vermutlich war der alte Bezugspunkt falsch: ohne Streckenzuwachs neu aufsetzen.
                anchor = sample
                outliersInRow = 0
            }
            return false
        }
        outliersInRow = 0

        let threshold = max(config.minStep, sample.horizontalAccuracy * config.accuracyStepFactor)
        if step < threshold {
            return true
        }
        totalDistance += step
        anchor = sample
        return true
    }
}
