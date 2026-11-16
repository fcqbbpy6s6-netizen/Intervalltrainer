import XCTest
@testable import IntervalCore

final class TrackingTests: XCTestCase {

    private let baseLatitude = 51.93
    private let baseLongitude = 8.87

    /// Punkt, der `north` Meter nördlich des Ausgangspunkts liegt.
    private func sample(t: Double, north: Double, accuracy: Double = 5) -> LocationSample {
        let latitude = baseLatitude + north / 6_371_000.0 * 180.0 / Double.pi
        return LocationSample(
            timestamp: t,
            latitude: latitude,
            longitude: baseLongitude,
            horizontalAccuracy: accuracy
        )
    }

    func testStraightLineIsSummed() {
        var tracker = DistanceTracker()
        for second in 0...100 {
            XCTAssertTrue(tracker.add(sample(t: Double(second), north: Double(second) * 3)))
        }
        XCTAssertEqual(tracker.totalDistance, 300, accuracy: 0.5)
    }

    func testInaccuratePointsAreRejected() {
        var tracker = DistanceTracker()
        XCTAssertTrue(tracker.add(sample(t: 0, north: 0)))
        XCTAssertFalse(tracker.add(sample(t: 1, north: 3, accuracy: 60)))
        XCTAssertFalse(tracker.add(sample(t: 2, north: 6, accuracy: -1)))
        XCTAssertEqual(tracker.totalDistance, 0, accuracy: 0.001)
        XCTAssertTrue(tracker.add(sample(t: 3, north: 9)))
        XCTAssertEqual(tracker.totalDistance, 9, accuracy: 0.1)
    }

    func testOutlierIsIgnored() {
        var tracker = DistanceTracker()
        for second in 0...10 {
            tracker.add(sample(t: Double(second), north: Double(second) * 3))
        }
        XCTAssertFalse(tracker.add(sample(t: 11, north: 500)))
        for second in 12...20 {
            XCTAssertTrue(tracker.add(sample(t: Double(second), north: Double(second) * 3)))
        }
        XCTAssertEqual(tracker.totalDistance, 60, accuracy: 0.5)
    }

    func testTrackerRecoversFromBadAnchor() {
        var tracker = DistanceTracker()
        // Erster Punkt liegt weit daneben, danach normale Bewegung.
        tracker.add(sample(t: 0, north: 5000))
        var accepted = 0
        for second in 1...30 {
            if tracker.add(sample(t: Double(second), north: Double(second) * 3)) {
                accepted += 1
            }
        }
        XCTAssertGreaterThan(accepted, 20)
        XCTAssertLessThan(tracker.totalDistance, 90)
        XCTAssertGreaterThan(tracker.totalDistance, 60)
    }

    func testStandingStillAddsNoDistance() {
        var tracker = DistanceTracker()
        let jitter: [Double] = [0, 0.8, -0.6, 1.1, -0.9, 0.4, -1.2, 0.7]
        for second in 0..<80 {
            tracker.add(sample(t: Double(second), north: jitter[second % jitter.count]))
        }
        XCTAssertEqual(tracker.totalDistance, 0, accuracy: 0.001)
    }

    func testPaceOverWindow() {
        var window = PaceWindow(window: 15)
        // 1000 m in 300 s = Pace 5:00.
        for second in 0...60 {
            window.add(time: Double(second), distance: Double(second) * 1000.0 / 300.0)
        }
        let pace = window.pace(now: 60)
        XCTAssertNotNil(pace)
        XCTAssertEqual(pace ?? 0, 300, accuracy: 0.5)
    }

    func testPaceFollowsSpeedChangeWithinWindow() {
        var window = PaceWindow(window: 15)
        var distance = 0.0
        for second in 1...60 {
            distance += 2.5
            window.add(time: Double(second), distance: distance)
        }
        for second in 61...90 {
            distance += 4
            window.add(time: Double(second), distance: distance)
        }
        // 4 m/s entspricht Pace 4:10.
        XCTAssertEqual(window.pace(now: 90) ?? 0, 250, accuracy: 0.5)
    }

    func testPaceIsNilWithoutData() {
        var window = PaceWindow(window: 15)
        XCTAssertNil(window.pace(now: 0))
        window.add(time: 0, distance: 0)
        window.add(time: 2, distance: 6)
        // Spanne noch zu kurz.
        XCTAssertNil(window.pace(now: 2))
    }

    func testPaceIsNilWhenStandingOrStale() {
        var window = PaceWindow(window: 15)
        for second in 0...30 {
            window.add(time: Double(second), distance: 100)
        }
        XCTAssertNil(window.pace(now: 30))

        var moving = PaceWindow(window: 15)
        for second in 0...30 {
            moving.add(time: Double(second), distance: Double(second) * 3)
        }
        XCTAssertNotNil(moving.pace(now: 31))
        XCTAssertNil(moving.pace(now: 60))
    }
}
