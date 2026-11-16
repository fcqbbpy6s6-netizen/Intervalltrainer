import Foundation

/// Mitgelieferte Beispielpläne.
public enum PlanTemplates {
    private static func warmup(minutes: Int) -> PlanItem {
        .phase(Phase(kind: .warmup, goal: .time(seconds: minutes * 60)))
    }

    private static func cooldown(minutes: Int) -> PlanItem {
        .phase(Phase(kind: .cooldown, goal: .time(seconds: minutes * 60)))
    }

    /// Liefert bei jedem Aufruf neue Pläne mit neuen IDs.
    public static func all() -> [Plan] {
        [
            Plan(name: "6× 400 m", items: [
                warmup(minutes: 10),
                .block(RepeatBlock(repeatCount: 6, phases: [
                    Phase(kind: .work, goal: .distance(meters: 400)),
                    Phase(kind: .recovery, goal: .distance(meters: 200))
                ])),
                cooldown(minutes: 10)
            ]),
            Plan(name: "8× 1 Minute", items: [
                warmup(minutes: 10),
                .block(RepeatBlock(repeatCount: 8, phases: [
                    Phase(kind: .work, goal: .time(seconds: 60)),
                    Phase(kind: .recovery, customName: "Locker", goal: .time(seconds: 90))
                ])),
                cooldown(minutes: 5)
            ]),
            Plan(name: "5× 1000 m mit Ziel-Pace", items: [
                .phase(Phase(kind: .warmup, goal: .distance(meters: 2000))),
                .block(RepeatBlock(repeatCount: 5, phases: [
                    Phase(
                        kind: .work,
                        goal: .distance(meters: 1000),
                        targetPace: PaceRange(fastSecPerKm: 285, slowSecPerKm: 300)
                    ),
                    Phase(kind: .recovery, goal: .time(seconds: 120))
                ])),
                .phase(Phase(kind: .cooldown, goal: .distance(meters: 1000)))
            ]),
            Plan(name: "Pyramide 1-2-3-2-1 Minuten", items: [
                warmup(minutes: 10),
                .phase(Phase(kind: .work, goal: .time(seconds: 60))),
                .phase(Phase(kind: .recovery, goal: .time(seconds: 60))),
                .phase(Phase(kind: .work, goal: .time(seconds: 120))),
                .phase(Phase(kind: .recovery, goal: .time(seconds: 120))),
                .phase(Phase(kind: .work, goal: .time(seconds: 180))),
                .phase(Phase(kind: .recovery, goal: .time(seconds: 180))),
                .phase(Phase(kind: .work, goal: .time(seconds: 120))),
                .phase(Phase(kind: .recovery, goal: .time(seconds: 120))),
                .phase(Phase(kind: .work, goal: .time(seconds: 60))),
                cooldown(minutes: 10)
            ]),
            Plan(name: "Tempodauerlauf 3× 10 Minuten", items: [
                warmup(minutes: 15),
                .block(RepeatBlock(repeatCount: 3, phases: [
                    Phase(kind: .work, customName: "Tempo", goal: .time(seconds: 600)),
                    Phase(kind: .recovery, goal: .time(seconds: 180))
                ])),
                cooldown(minutes: 10)
            ])
        ]
    }
}
