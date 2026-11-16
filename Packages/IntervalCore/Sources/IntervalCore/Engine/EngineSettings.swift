import Foundation

/// Schwellen und Abstände der Engine.
public struct EngineSettings: Equatable, Sendable {
    /// Halbzeit-Ansage nur bei Zeitphasen ab dieser Länge.
    public var halfwayMinSeconds = 60
    /// Halbzeit-Ansage nur bei Streckenphasen ab dieser Länge.
    public var halfwayMinMeters = 400
    /// „Noch x Sekunden“.
    public var timeWarningSeconds = 10
    public var timeWarningMinPhaseSeconds = 20
    /// „Noch x Meter“.
    public var distanceWarningMeters = 50
    public var distanceWarningMinPhaseMeters = 150
    /// Countdown ab dieser Zahl (3 = „drei, zwei, eins“), 0 = aus.
    public var countdownFrom = 3
    public var countdownMinPhaseSeconds = 10
    /// Frühestens so viele Sekunden nach Phasenbeginn kommt ein Pace-Hinweis.
    public var paceHintDelay: TimeInterval = 20
    /// Mindestabstand zwischen zwei Pace-Hinweisen.
    public var paceHintInterval: TimeInterval = 30
    /// Zusätzliche Toleranz um den Zielbereich in Sekunden pro Kilometer.
    public var paceToleranceSecPerKm: Double = 3

    public init() {}
}
