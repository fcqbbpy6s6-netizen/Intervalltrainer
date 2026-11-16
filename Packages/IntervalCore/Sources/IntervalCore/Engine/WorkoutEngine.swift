import Foundation

/// Zustandsautomat des Trainings.
///
/// Die Engine kennt weder Uhr noch GPS. Sie bekommt von außen eine fortlaufende Zeit
/// (Sekunden, beliebiger Nullpunkt) und die bisher gemessene Gesamtstrecke (Meter)
/// und meldet Ereignisse zurück. Während einer Pause werden Zeit und Strecke verworfen.
public final class WorkoutEngine {
    public let steps: [WorkoutStep]
    public var settings: EngineSettings

    public private(set) var state: WorkoutState = .ready
    public private(set) var stepIndex = 0
    /// Aktive Zeit in der aktuellen Phase.
    public private(set) var phaseTime: TimeInterval = 0
    /// Strecke in der aktuellen Phase.
    public private(set) var phaseDistance: Double = 0
    /// Aktive Gesamtzeit ohne Pausen.
    public private(set) var totalTime: TimeInterval = 0
    /// Gesamtstrecke ohne Pausen.
    public private(set) var totalDistance: Double = 0
    public private(set) var results: [PhaseResult] = []
    public private(set) var summary: WorkoutSummary?

    private var lastTime: TimeInterval?
    private var lastDistance: Double = 0

    private var halfwayDone = false
    private var warningDone = false
    private var lastCountdown = Int.max
    private var lastPaceHintAt: TimeInterval = -1_000_000
    private var activeHint: PaceHint?

    public init(plan: Plan, settings: EngineSettings = EngineSettings()) {
        self.steps = plan.flattened()
        self.settings = settings
    }

    // MARK: - Abfragen

    public var currentStep: WorkoutStep? {
        guard state != .finished, steps.indices.contains(stepIndex) else { return nil }
        return steps[stepIndex]
    }

    public var nextStep: WorkoutStep? {
        guard state != .finished, steps.indices.contains(stepIndex + 1) else { return nil }
        return steps[stepIndex + 1]
    }

    /// Restzeit der aktuellen Phase, nur bei Zeitphasen.
    public var remainingTime: TimeInterval? {
        guard let step = currentStep, case .time(let seconds) = step.phase.goal else { return nil }
        return max(0, Double(max(1, seconds)) - phaseTime)
    }

    /// Reststrecke der aktuellen Phase, nur bei Streckenphasen.
    public var remainingDistance: Double? {
        guard let step = currentStep, case .distance(let meters) = step.phase.goal else { return nil }
        return max(0, Double(max(1, meters)) - phaseDistance)
    }

    /// Fortschritt der aktuellen Phase von 0 bis 1.
    public var phaseProgress: Double {
        guard let step = currentStep else { return state == .finished ? 1 : 0 }
        switch step.phase.goal {
        case .time(let seconds):
            return min(1, max(0, phaseTime / Double(max(1, seconds))))
        case .distance(let meters):
            return min(1, max(0, phaseDistance / Double(max(1, meters))))
        }
    }

    /// Fortschritt im gesamten Plan von 0 bis 1 (nach Schritten).
    public var planProgress: Double {
        guard !steps.isEmpty else { return 1 }
        if state == .finished { return 1 }
        return min(1, (Double(stepIndex) + phaseProgress) / Double(steps.count))
    }

    // MARK: - Steuerung

    /// Startet das Training.
    @discardableResult
    public func start(time: TimeInterval, distance: Double) -> [WorkoutEvent] {
        guard state == .ready else { return [] }
        lastTime = time
        lastDistance = distance
        var events: [WorkoutEvent] = []
        guard !steps.isEmpty else {
            finish(completed: true, events: &events)
            return events
        }
        state = .running
        resetPhaseFlags()
        events.append(.phaseStarted(steps[0]))
        return events
    }

    /// Meldet neue Messwerte. Regelmäßig aufrufen, auch während einer Pause.
    @discardableResult
    public func update(time: TimeInterval, distance: Double, paceSecPerKm: Double? = nil) -> [WorkoutEvent] {
        let deltaTime = max(0, time - (lastTime ?? time))
        let deltaDistance = max(0, distance - lastDistance)
        lastTime = time
        lastDistance = distance
        guard state == .running else { return [] }

        totalTime += deltaTime
        totalDistance += deltaDistance
        phaseTime += deltaTime
        phaseDistance += deltaDistance

        var events: [WorkoutEvent] = []

        // Phasen abschließen. Der Überschuss wird in die nächste Phase übertragen.
        while state == .running, let step = currentStep {
            switch step.phase.goal {
            case .time(let seconds):
                let over = phaseTime - Double(max(1, seconds))
                if over < 0 { break }
                advance(skipped: false, carryTime: over, carryDistance: 0, events: &events)
                continue
            case .distance(let meters):
                let over = phaseDistance - Double(max(1, meters))
                if over < 0 { break }
                advance(skipped: false, carryTime: 0, carryDistance: over, events: &events)
                continue
            }
            break
        }

        guard state == .running, let step = currentStep else { return events }
        appendProgressEvents(for: step, to: &events)
        appendPaceEvents(for: step, pace: paceSecPerKm, to: &events)
        return events
    }

    @discardableResult
    public func pause() -> [WorkoutEvent] {
        guard state == .running else { return [] }
        state = .paused
        return [.paused]
    }

    @discardableResult
    public func resume(time: TimeInterval, distance: Double) -> [WorkoutEvent] {
        guard state == .paused else { return [] }
        lastTime = time
        lastDistance = distance
        state = .running
        return [.resumed]
    }

    /// Springt zur nächsten Phase. Nach der letzten Phase endet das Training.
    @discardableResult
    public func skip() -> [WorkoutEvent] {
        guard state == .running || state == .paused else { return [] }
        var events: [WorkoutEvent] = []
        advance(skipped: true, carryTime: 0, carryDistance: 0, events: &events)
        return events
    }

    /// Beendet das Training vorzeitig.
    @discardableResult
    public func stop() -> [WorkoutEvent] {
        guard state != .finished else { return [] }
        var events: [WorkoutEvent] = []
        if state != .ready, steps.indices.contains(stepIndex) {
            results.append(PhaseResult(
                step: steps[stepIndex],
                seconds: phaseTime,
                meters: phaseDistance,
                skipped: true
            ))
        }
        finish(completed: false, events: &events)
        return events
    }

    // MARK: - Intern

    private func resetPhaseFlags() {
        halfwayDone = false
        warningDone = false
        lastCountdown = Int.max
        activeHint = nil
    }

    private func advance(skipped: Bool, carryTime: TimeInterval, carryDistance: Double, events: inout [WorkoutEvent]) {
        guard steps.indices.contains(stepIndex) else { return }
        results.append(PhaseResult(
            step: steps[stepIndex],
            seconds: max(0, phaseTime - carryTime),
            meters: max(0, phaseDistance - carryDistance),
            skipped: skipped
        ))
        stepIndex += 1
        phaseTime = carryTime
        phaseDistance = carryDistance
        resetPhaseFlags()
        if stepIndex >= steps.count {
            finish(completed: true, events: &events)
        } else {
            events.append(.phaseStarted(steps[stepIndex]))
        }
    }

    private func finish(completed: Bool, events: inout [WorkoutEvent]) {
        state = .finished
        phaseTime = 0
        phaseDistance = 0
        let result = WorkoutSummary(
            totalSeconds: totalTime,
            totalMeters: totalDistance,
            completed: completed,
            stepCount: steps.count,
            results: results
        )
        summary = result
        events.append(.finished(result))
    }

    private func appendProgressEvents(for step: WorkoutStep, to events: inout [WorkoutEvent]) {
        switch step.phase.goal {
        case .time(let seconds):
            let goal = Double(max(1, seconds))
            let remaining = goal - phaseTime

            if !halfwayDone, seconds >= settings.halfwayMinSeconds, phaseTime >= goal / 2 {
                halfwayDone = true
                events.append(.halfwayTime(remainingSeconds: Int(remaining.rounded())))
            }

            let warning = settings.timeWarningSeconds
            if !warningDone, warning > 0, seconds >= settings.timeWarningMinPhaseSeconds, remaining <= Double(warning) {
                warningDone = true
                // Kommt die Meldung deutlich zu spät, lieber weglassen.
                if remaining > Double(warning) - 2 {
                    events.append(.timeWarning(seconds: warning))
                }
            }

            if settings.countdownFrom > 0, seconds >= settings.countdownMinPhaseSeconds {
                let number = Int(remaining.rounded(.up))
                if number >= 1, number <= settings.countdownFrom, number < lastCountdown {
                    lastCountdown = number
                    events.append(.countdown(number))
                }
            }

        case .distance(let meters):
            let goal = Double(max(1, meters))
            let remaining = goal - phaseDistance

            if !halfwayDone, meters >= settings.halfwayMinMeters, phaseDistance >= goal / 2 {
                halfwayDone = true
                let rounded = Int((remaining / 10).rounded()) * 10
                events.append(.halfwayDistance(remainingMeters: rounded))
            }

            let warning = settings.distanceWarningMeters
            if !warningDone, warning > 0, meters >= settings.distanceWarningMinPhaseMeters, remaining <= Double(warning) {
                warningDone = true
                if remaining > Double(warning) / 2 {
                    events.append(.distanceWarning(meters: warning))
                }
            }
        }
    }

    private func appendPaceEvents(for step: WorkoutStep, pace: Double?, to events: inout [WorkoutEvent]) {
        guard let range = step.phase.targetPace, let pace = pace, pace > 0 else { return }
        guard phaseTime >= settings.paceHintDelay else { return }

        // Kurz vor Phasenende keine Pace-Hinweise mehr.
        switch step.phase.goal {
        case .time(let seconds):
            if Double(max(1, seconds)) - phaseTime <= 12 { return }
        case .distance(let meters):
            if Double(max(1, meters)) - phaseDistance <= 60 { return }
        }

        let lower = Double(min(range.fastSecPerKm, range.slowSecPerKm)) - settings.paceToleranceSecPerKm
        let upper = Double(max(range.fastSecPerKm, range.slowSecPerKm)) + settings.paceToleranceSecPerKm
        let sinceLast = totalTime - lastPaceHintAt

        if pace < lower || pace > upper {
            let hint: PaceHint = pace < lower ? .slower : .faster
            if sinceLast >= settings.paceHintInterval {
                lastPaceHintAt = totalTime
                activeHint = hint
                events.append(.paceHint(hint))
            }
        } else if activeHint != nil, sinceLast >= min(10, settings.paceHintInterval) {
            activeHint = nil
            lastPaceHintAt = totalTime
            events.append(.paceHint(.onTarget))
        }
    }
}
