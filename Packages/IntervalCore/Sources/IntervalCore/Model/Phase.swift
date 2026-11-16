import Foundation

/// Art einer Phase im Trainingsplan.
public enum PhaseKind: String, Codable, CaseIterable, Hashable, Sendable {
    case warmup
    case work
    case recovery
    case cooldown

    /// Name für die Anzeige.
    public var displayName: String {
        switch self {
        case .warmup: return "Einlaufen"
        case .work: return "Belastung"
        case .recovery: return "Trabpause"
        case .cooldown: return "Auslaufen"
        }
    }
}

/// Ziel einer Phase: entweder eine Zeit oder eine Strecke.
public enum PhaseGoal: Codable, Equatable, Hashable, Sendable {
    case time(seconds: Int)
    case distance(meters: Int)

    public var isTime: Bool {
        switch self {
        case .time: return true
        case .distance: return false
        }
    }
}

/// Ziel-Pace als Bereich in Sekunden pro Kilometer (kleiner Wert = schneller).
public struct PaceRange: Codable, Equatable, Hashable, Sendable {
    public var fastSecPerKm: Int
    public var slowSecPerKm: Int

    public init(fastSecPerKm: Int, slowSecPerKm: Int) {
        let a = max(1, fastSecPerKm)
        let b = max(1, slowSecPerKm)
        self.fastSecPerKm = min(a, b)
        self.slowSecPerKm = max(a, b)
    }

    /// Mitte des Bereichs, für Schätzungen.
    public var midSecPerKm: Double {
        Double(fastSecPerKm + slowSecPerKm) / 2
    }
}

/// Eine einzelne Phase des Plans.
public struct Phase: Codable, Identifiable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var kind: PhaseKind
    public var customName: String?
    public var goal: PhaseGoal
    public var targetPace: PaceRange?

    public init(
        id: UUID = UUID(),
        kind: PhaseKind,
        customName: String? = nil,
        goal: PhaseGoal,
        targetPace: PaceRange? = nil
    ) {
        self.id = id
        self.kind = kind
        self.customName = customName
        self.goal = goal
        self.targetPace = targetPace
    }

    /// Eigener Name ohne Leerraum, oder nil, wenn keiner gesetzt ist.
    public var trimmedCustomName: String? {
        guard let name = customName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return nil
        }
        return name
    }

    /// Name für die Anzeige: eigener Name, sonst der Typ.
    public var displayName: String {
        trimmedCustomName ?? kind.displayName
    }
}
