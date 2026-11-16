import Foundation

/// Gesamtwerte eines Plans für die Vorschau.
public struct PlanSummary: Equatable, Sendable {
    /// Summe aller Zeitphasen in Sekunden.
    public var timedSeconds: Int = 0
    /// Summe aller Streckenphasen in Metern.
    public var distanceMeters: Int = 0
    public var hasTimePhases = false
    public var hasDistancePhases = false
    /// Geschätzte Gesamtdauer, wenn jede Streckenphase eine Ziel-Pace hat.
    public var estimatedSeconds: Int?
    /// Geschätzte Gesamtstrecke, wenn jede Zeitphase eine Ziel-Pace hat.
    public var estimatedMeters: Int?
    public var stepCount = 0

    /// Exakte Dauer, nur wenn der Plan ausschließlich Zeitphasen hat.
    public var exactSeconds: Int? {
        hasDistancePhases ? nil : timedSeconds
    }

    /// Exakte Strecke, nur wenn der Plan ausschließlich Streckenphasen hat.
    public var exactMeters: Int? {
        hasTimePhases ? nil : distanceMeters
    }

    /// Kurztext für Listen und Vorschau.
    public var text: String {
        if stepCount == 0 {
            return "Noch keine Phasen"
        }
        var parts: [String] = []
        if hasTimePhases && !hasDistancePhases {
            parts.append("Dauer " + RunFormat.clock(timedSeconds))
            if let meters = estimatedMeters {
                parts.append("ca. " + RunFormat.distance(meters: meters))
            }
        } else if hasDistancePhases && !hasTimePhases {
            parts.append("Strecke " + RunFormat.distance(meters: distanceMeters))
            if let seconds = estimatedSeconds {
                parts.append("ca. " + RunFormat.clock(seconds))
            }
        } else {
            parts.append(RunFormat.clock(timedSeconds) + " + " + RunFormat.distance(meters: distanceMeters))
            if let seconds = estimatedSeconds {
                parts.append("gesamt ca. " + RunFormat.clock(seconds))
            } else if let meters = estimatedMeters {
                parts.append("gesamt ca. " + RunFormat.distance(meters: meters))
            }
        }
        return parts.joined(separator: " · ")
    }
}

extension Plan {
    /// Berechnet Gesamtdauer und Gesamtstrecke, soweit möglich.
    public var summary: PlanSummary {
        var result = PlanSummary()
        var extraSeconds = 0.0
        var extraMeters = 0.0
        var allDistancePhasesHavePace = true
        var allTimePhasesHavePace = true

        let steps = flattened()
        result.stepCount = steps.count
        for step in steps {
            let phase = step.phase
            switch phase.goal {
            case .time(let seconds):
                result.hasTimePhases = true
                result.timedSeconds += seconds
                if let pace = phase.targetPace, pace.midSecPerKm > 0 {
                    extraMeters += Double(seconds) / pace.midSecPerKm * 1000
                } else {
                    allTimePhasesHavePace = false
                }
            case .distance(let meters):
                result.hasDistancePhases = true
                result.distanceMeters += meters
                if let pace = phase.targetPace {
                    extraSeconds += Double(meters) / 1000 * pace.midSecPerKm
                } else {
                    allDistancePhasesHavePace = false
                }
            }
        }

        if result.hasDistancePhases && allDistancePhasesHavePace {
            result.estimatedSeconds = result.timedSeconds + Int(extraSeconds.rounded())
        }
        if result.hasTimePhases && allTimePhasesHavePace {
            let total = Double(result.distanceMeters) + extraMeters
            result.estimatedMeters = Int((total / 100).rounded()) * 100
        }
        return result
    }
}
