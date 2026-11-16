import Foundation

/// Ein Text für die Sprachausgabe mit Priorität.
public struct Announcement: Equatable, Sendable {
    public enum Priority: Sendable {
        /// Wird nur gesprochen, wenn gerade nichts anderes läuft (Pace-Hinweise).
        case low
        /// Wird hinten angestellt.
        case normal
        /// Unterbricht laufende Ansagen (Phasenwechsel, Countdown).
        case high
    }

    public var text: String
    public var priority: Priority

    public init(text: String, priority: Priority) {
        self.text = text
        self.priority = priority
    }
}

/// Welche Ansagetypen aktiv sind.
public struct AnnouncementSettings: Equatable, Sendable {
    public var phaseChanges = true
    public var countdown = true
    public var halfway = true
    public var paceHints = true
    public var summary = true

    public init() {}
}

/// Baut aus Engine-Ereignissen deutsche Ansagetexte.
public enum AnnouncementBuilder {
    public static func announcement(
        for event: WorkoutEvent,
        settings: AnnouncementSettings = AnnouncementSettings()
    ) -> Announcement? {
        switch event {
        case .phaseStarted(let step):
            guard settings.phaseChanges else { return nil }
            return Announcement(text: phaseText(step), priority: .high)

        case .halfwayTime(let remainingSeconds):
            guard settings.halfway else { return nil }
            return Announcement(
                text: "Halbzeit. Noch \(GermanSpeech.duration(seconds: remainingSeconds)).",
                priority: .normal
            )

        case .halfwayDistance(let remainingMeters):
            guard settings.halfway else { return nil }
            return Announcement(
                text: "Halbzeit. Noch \(GermanSpeech.distance(meters: remainingMeters)).",
                priority: .normal
            )

        case .timeWarning(let seconds):
            guard settings.countdown else { return nil }
            return Announcement(text: "Noch \(GermanSpeech.duration(seconds: seconds)).", priority: .normal)

        case .distanceWarning(let meters):
            guard settings.countdown else { return nil }
            return Announcement(text: "Noch \(GermanSpeech.distance(meters: meters)).", priority: .normal)

        case .countdown(let number):
            guard settings.countdown else { return nil }
            return Announcement(text: GermanSpeech.spell(number), priority: .high)

        case .paceHint(let hint):
            guard settings.paceHints else { return nil }
            switch hint {
            case .faster: return Announcement(text: "Schneller.", priority: .low)
            case .slower: return Announcement(text: "Langsamer.", priority: .low)
            case .onTarget: return Announcement(text: "Pace passt.", priority: .low)
            }

        case .paused:
            guard settings.phaseChanges else { return nil }
            return Announcement(text: "Pause.", priority: .high)

        case .resumed:
            guard settings.phaseChanges else { return nil }
            return Announcement(text: "Weiter.", priority: .high)

        case .finished(let summary):
            if settings.summary {
                return Announcement(text: summaryText(summary), priority: .high)
            }
            guard settings.phaseChanges else { return nil }
            return Announcement(text: "Training beendet.", priority: .high)
        }
    }

    /// Ansage zum Phasenbeginn, z. B.
    /// „Intervall drei von sechs. Vierhundert Meter schnell. Ziel-Pace vier Minuten dreißig.“
    public static func phaseText(_ step: WorkoutStep) -> String {
        let phase = step.phase
        var parts: [String] = []

        if phase.kind == .work, let repetition = step.repetition, let count = step.repetitionCount {
            parts.append("Intervall \(GermanSpeech.spell(repetition)) von \(GermanSpeech.spell(count))")
        }

        let goal: String
        switch phase.goal {
        case .time(let seconds): goal = GermanSpeech.duration(seconds: seconds)
        case .distance(let meters): goal = GermanSpeech.distance(meters: meters)
        }

        if let name = phase.trimmedCustomName {
            parts.append(name)
            parts.append(goal)
        } else {
            switch phase.kind {
            case .warmup:
                parts.append("Einlaufen")
                parts.append(goal)
            case .work:
                parts.append("\(goal) schnell")
            case .recovery:
                parts.append("\(goal) Trabpause")
            case .cooldown:
                parts.append("Auslaufen")
                parts.append(goal)
            }
        }

        if let pace = phase.targetPace {
            parts.append("Ziel-Pace \(GermanSpeech.paceRange(pace))")
        }

        return sentences(parts)
    }

    /// Ansage am Ende des Trainings.
    public static func summaryText(_ summary: WorkoutSummary) -> String {
        var parts = ["Training beendet"]
        let duration = GermanSpeech.duration(seconds: Int(summary.totalSeconds.rounded()))
        if summary.totalMeters >= 50 {
            parts.append("\(GermanSpeech.kilometers(meters: summary.totalMeters)) in \(duration)")
            if let pace = summary.averagePaceSecPerKm {
                parts.append("Durchschnitts-Pace \(GermanSpeech.pace(secPerKm: Int(pace.rounded()))) pro Kilometer")
            }
        } else {
            parts.append("Dauer \(duration)")
        }
        return sentences(parts)
    }

    private static func sentences(_ parts: [String]) -> String {
        parts.map { capitalizedFirst($0) }.joined(separator: ". ") + "."
    }

    private static func capitalizedFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased() + text.dropFirst()
    }
}
