import Combine
import CoreLocation
import Foundation
import IntervalCore

/// Werte für die Laufanzeige, auf ganze Sekunden und Meter gerundet,
/// damit sich die Oberfläche nur etwa einmal pro Sekunde neu zeichnet.
struct RunDisplay: Equatable {
    var state: WorkoutState = .ready
    var step: WorkoutStep?
    var nextStep: WorkoutStep?
    var stepCount = 0
    var remainingSeconds: Int?
    var remainingMeters: Int?
    var phaseSeconds = 0
    var phaseMeters = 0
    var phaseProgress = 0.0
    var planProgress = 0.0
    var totalSeconds = 0
    var totalMeters = 0.0
    var paceSecPerKm: Int?
}

/// Verbindet Uhr, GPS, Engine und Sprachausgabe für einen Lauf.
final class WorkoutSession: ObservableObject {
    let plan: Plan

    @Published private(set) var display = RunDisplay()
    @Published private(set) var summary: WorkoutSummary?
    /// Horizontale GPS-Genauigkeit in Metern, nil = noch kein Empfang.
    @Published private(set) var gpsAccuracy: Int?
    @Published private(set) var authorization: CLAuthorizationStatus

    private let engine: WorkoutEngine
    private let speech: SpeechService
    private let location: LocationService
    private let settings: SettingsStore

    private var tracker = DistanceTracker()
    private var paceWindow = PaceWindow(window: 15)
    private var timer: Timer?
    private var lastFix: Date?

    init(plan: Plan, speech: SpeechService, location: LocationService, settings: SettingsStore) {
        self.plan = plan
        self.speech = speech
        self.location = location
        self.settings = settings
        var engineSettings = EngineSettings()
        engineSettings.paceHintInterval = TimeInterval(settings.paceHintInterval)
        self.engine = WorkoutEngine(plan: plan, settings: engineSettings)
        self.authorization = location.authorizationStatus
        refreshDisplay()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Lebenszyklus der Ansicht

    /// Beim Öffnen der Laufansicht: GPS schon vor dem Start suchen lassen.
    func prepare() {
        location.onLocation = { [weak self] newLocation in
            self?.handle(newLocation)
        }
        location.onAuthorizationChange = { [weak self] status in
            self?.authorization = status
        }
        authorization = location.authorizationStatus
        if engine.state != .finished {
            location.start()
        }
    }

    /// Beim Schließen der Laufansicht.
    func teardown() {
        timer?.invalidate()
        timer = nil
        location.stop()
        location.onLocation = nil
        location.onAuthorizationChange = nil
    }

    // MARK: - Steuerung

    func start() {
        guard engine.state == .ready else { return }
        tracker.reset()
        paceWindow.reset()
        process(engine.start(time: Self.now(), distance: tracker.totalDistance))
        startTimer()
        refreshDisplay()
    }

    func togglePause() {
        switch engine.state {
        case .running:
            process(engine.pause())
        case .paused:
            process(engine.resume(time: Self.now(), distance: tracker.totalDistance))
        default:
            break
        }
        refreshDisplay()
    }

    func skip() {
        process(engine.skip())
        refreshDisplay()
    }

    func stop() {
        process(engine.stop())
        refreshDisplay()
    }

    // MARK: - Intern

    /// Fortlaufende Uhr in Sekunden, unabhängig von Änderungen der Systemzeit.
    private static func now() -> TimeInterval {
        Double(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)) / 1_000_000_000
    }

    private func startTimer() {
        timer?.invalidate()
        let newTimer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.tick()
        }
        newTimer.tolerance = 0.02
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func tick() {
        let pace = paceWindow.pace(now: Date().timeIntervalSinceReferenceDate)
        let events = engine.update(time: Self.now(), distance: tracker.totalDistance, paceSecPerKm: pace)
        process(events)
        if let lastFix = lastFix, Date().timeIntervalSince(lastFix) > 10, gpsAccuracy != nil {
            gpsAccuracy = nil
        }
        refreshDisplay()
    }

    private func process(_ events: [WorkoutEvent]) {
        guard !events.isEmpty else { return }
        speech.config = settings.speechConfig
        let announcementSettings = settings.announcementSettings
        for event in events {
            if case .finished(let result) = event {
                summary = result
                timer?.invalidate()
                timer = nil
                location.stop()
            }
            if let announcement = AnnouncementBuilder.announcement(for: event, settings: announcementSettings) {
                speech.speak(announcement)
            }
        }
    }

    private func handle(_ newLocation: CLLocation) {
        guard newLocation.horizontalAccuracy >= 0 else { return }
        // Alte, zwischengespeicherte Positionen ignorieren.
        guard abs(newLocation.timestamp.timeIntervalSinceNow) < 10 else { return }

        lastFix = Date()
        let accuracy = Int(newLocation.horizontalAccuracy.rounded())
        if gpsAccuracy != accuracy {
            gpsAccuracy = accuracy
        }

        guard engine.state == .running || engine.state == .paused else { return }
        let sample = LocationSample(
            timestamp: newLocation.timestamp.timeIntervalSinceReferenceDate,
            latitude: newLocation.coordinate.latitude,
            longitude: newLocation.coordinate.longitude,
            horizontalAccuracy: newLocation.horizontalAccuracy
        )
        if tracker.add(sample) {
            paceWindow.add(time: sample.timestamp, distance: tracker.totalDistance)
        }
    }

    private func refreshDisplay() {
        var next = RunDisplay()
        next.state = engine.state
        next.step = engine.currentStep
        next.nextStep = engine.nextStep
        next.stepCount = engine.steps.count
        if let remaining = engine.remainingTime {
            next.remainingSeconds = Int(remaining.rounded(.up))
        }
        if let remaining = engine.remainingDistance {
            next.remainingMeters = Int(remaining.rounded(.up))
        }
        next.phaseSeconds = Int(engine.phaseTime)
        next.phaseMeters = Int(engine.phaseDistance)
        next.phaseProgress = (engine.phaseProgress * 200).rounded() / 200
        next.planProgress = (engine.planProgress * 200).rounded() / 200
        next.totalSeconds = Int(engine.totalTime)
        next.totalMeters = (engine.totalDistance / 10).rounded() * 10
        if engine.state == .running,
           let pace = paceWindow.pace(now: Date().timeIntervalSinceReferenceDate) {
            next.paceSecPerKm = Int(pace.rounded())
        }
        if next != display {
            display = next
        }
    }
}
