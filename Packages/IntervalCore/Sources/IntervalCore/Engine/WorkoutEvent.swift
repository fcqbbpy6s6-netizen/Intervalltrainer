import Foundation

/// Zustand des Trainings.
public enum WorkoutState: String, Equatable, Sendable {
    case ready
    case running
    case paused
    case finished
}

/// Hinweis zur Ziel-Pace.
public enum PaceHint: Equatable, Sendable {
    /// Zu langsam unterwegs: schneller laufen.
    case faster
    /// Zu schnell unterwegs: langsamer laufen.
    case slower
    /// Wieder im Zielbereich.
    case onTarget
}

/// Ergebnis einer absolvierten Phase.
public struct PhaseResult: Equatable, Identifiable, Sendable {
    public let step: WorkoutStep
    public let seconds: TimeInterval
    public let meters: Double
    public let skipped: Bool

    public var id: Int { step.index }

    public init(step: WorkoutStep, seconds: TimeInterval, meters: Double, skipped: Bool) {
        self.step = step
        self.seconds = seconds
        self.meters = meters
        self.skipped = skipped
    }

    /// Durchschnitts-Pace der Phase in Sekunden pro Kilometer.
    public var paceSecPerKm: Double? {
        guard meters >= 20, seconds > 0 else { return nil }
        return seconds / meters * 1000
    }
}

/// Zusammenfassung am Ende des Trainings.
public struct WorkoutSummary: Equatable, Sendable {
    public let totalSeconds: TimeInterval
    public let totalMeters: Double
    /// true, wenn der Plan bis zum Ende durchlaufen wurde.
    public let completed: Bool
    public let stepCount: Int
    public let results: [PhaseResult]

    public init(
        totalSeconds: TimeInterval,
        totalMeters: Double,
        completed: Bool,
        stepCount: Int,
        results: [PhaseResult]
    ) {
        self.totalSeconds = totalSeconds
        self.totalMeters = totalMeters
        self.completed = completed
        self.stepCount = stepCount
        self.results = results
    }

    public var averagePaceSecPerKm: Double? {
        guard totalMeters >= 50, totalSeconds > 0 else { return nil }
        return totalSeconds / totalMeters * 1000
    }
}

/// Ereignisse, die die Engine meldet.
public enum WorkoutEvent: Equatable, Sendable {
    case phaseStarted(WorkoutStep)
    case halfwayTime(remainingSeconds: Int)
    case halfwayDistance(remainingMeters: Int)
    /// „Noch 10 Sekunden“.
    case timeWarning(seconds: Int)
    /// „Noch 50 Meter“.
    case distanceWarning(meters: Int)
    /// 3, 2, 1 vor dem Ende einer Zeitphase.
    case countdown(Int)
    case paceHint(PaceHint)
    case paused
    case resumed
    case finished(WorkoutSummary)
}
