import Foundation

/// Ein Schritt des ausgerollten Plans: eine Phase mit ihrer Wiederholung.
public struct WorkoutStep: Equatable, Identifiable, Sendable {
    public let index: Int
    public let phase: Phase
    /// Nummer der Wiederholung (ab 1), nur innerhalb eines Blocks mit mehr als einer Wiederholung.
    public let repetition: Int?
    public let repetitionCount: Int?

    public var id: Int { index }

    public init(index: Int, phase: Phase, repetition: Int? = nil, repetitionCount: Int? = nil) {
        self.index = index
        self.phase = phase
        self.repetition = repetition
        self.repetitionCount = repetitionCount
    }
}

extension Plan {
    /// Rollt Wiederholungsblöcke zu einer linearen Liste von Schritten aus.
    public func flattened() -> [WorkoutStep] {
        var steps: [WorkoutStep] = []
        for item in items {
            switch item {
            case .phase(let phase):
                steps.append(WorkoutStep(index: steps.count, phase: phase))
            case .block(let block):
                let count = max(1, block.repeatCount)
                for repetition in 1...count {
                    for phase in block.phases {
                        steps.append(WorkoutStep(
                            index: steps.count,
                            phase: phase,
                            repetition: count > 1 ? repetition : nil,
                            repetitionCount: count > 1 ? count : nil
                        ))
                    }
                }
            }
        }
        return steps
    }
}
