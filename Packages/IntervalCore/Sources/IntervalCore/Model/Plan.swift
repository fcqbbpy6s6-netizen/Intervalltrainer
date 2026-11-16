import Foundation

/// Mehrere Phasen, die n-mal wiederholt werden.
public struct RepeatBlock: Codable, Identifiable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var repeatCount: Int
    public var phases: [Phase]

    public init(id: UUID = UUID(), repeatCount: Int, phases: [Phase]) {
        self.id = id
        self.repeatCount = max(1, repeatCount)
        self.phases = phases
    }
}

/// Ein Eintrag im Plan: einzelne Phase oder Wiederholungsblock.
public enum PlanItem: Codable, Identifiable, Equatable, Hashable, Sendable {
    case phase(Phase)
    case block(RepeatBlock)

    public var id: UUID {
        switch self {
        case .phase(let phase): return phase.id
        case .block(let block): return block.id
        }
    }
}

/// Ein kompletter Intervallplan.
public struct Plan: Codable, Identifiable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var items: [PlanItem]

    public init(id: UUID = UUID(), name: String, items: [PlanItem] = []) {
        self.id = id
        self.name = name
        self.items = items
    }

    /// Kopie mit neuen IDs und dem Zusatz „(Kopie)“ im Namen.
    public func duplicated() -> Plan {
        var copy = self
        copy.id = UUID()
        copy.name = name + " (Kopie)"
        copy.items = items.map { item in
            switch item {
            case .phase(var phase):
                phase.id = UUID()
                return .phase(phase)
            case .block(var block):
                block.id = UUID()
                block.phases = block.phases.map { phase in
                    var p = phase
                    p.id = UUID()
                    return p
                }
                return .block(block)
            }
        }
        return copy
    }
}
