import XCTest
@testable import IntervalCore

/// Simuliert Zeit und Strecke in 1-Sekunden-Schritten.
private final class Sim {
    let engine: WorkoutEngine
    let startTime: Double = 1000
    var time: Double = 1000
    var distance: Double = 50
    var log: [(t: Double, event: WorkoutEvent)] = []

    init(_ plan: Plan, settings: EngineSettings = EngineSettings()) {
        engine = WorkoutEngine(plan: plan, settings: settings)
    }

    var elapsed: Double { time - startTime }
    var events: [WorkoutEvent] { log.map { $0.event } }

    func record(_ events: [WorkoutEvent]) {
        for event in events {
            log.append((t: elapsed, event: event))
        }
    }

    func start() {
        record(engine.start(time: time, distance: distance))
    }

    func advance(_ seconds: Int, speed: Double = 0, pace: Double? = nil) {
        for _ in 0..<seconds {
            time += 1
            distance += speed
            record(engine.update(time: time, distance: distance, paceSecPerKm: pace))
        }
    }

    func times(of event: WorkoutEvent) -> [Double] {
        log.filter { $0.event == event }.map { $0.t }
    }

    var startedStepIndexes: [Int] {
        events.compactMap { event -> Int? in
            if case .phaseStarted(let step) = event { return step.index }
            return nil
        }
    }

    var summary: WorkoutSummary? {
        for event in events {
            if case .finished(let summary) = event { return summary }
        }
        return nil
    }
}

private func timePhase(_ seconds: Int, kind: PhaseKind = .work, pace: PaceRange? = nil) -> Phase {
    Phase(kind: kind, goal: .time(seconds: seconds), targetPace: pace)
}

private func distancePhase(_ meters: Int, kind: PhaseKind = .work, pace: PaceRange? = nil) -> Phase {
    Phase(kind: kind, goal: .distance(meters: meters), targetPace: pace)
}

final class WorkoutEngineTests: XCTestCase {

    func testFlattenRollsOutBlocks() {
        let plan = Plan(name: "Test", items: [
            .phase(timePhase(600, kind: .warmup)),
            .block(RepeatBlock(repeatCount: 3, phases: [
                distancePhase(400),
                distancePhase(200, kind: .recovery)
            ])),
            .phase(timePhase(300, kind: .cooldown))
        ])
        let steps = plan.flattened()
        XCTAssertEqual(steps.count, 8)
        XCTAssertEqual(steps.map { $0.index }, Array(0..<8))
        XCTAssertNil(steps[0].repetition)
        XCTAssertEqual(steps[1].repetition, 1)
        XCTAssertEqual(steps[1].repetitionCount, 3)
        XCTAssertEqual(steps[5].repetition, 3)
        XCTAssertEqual(steps[6].phase.kind, .recovery)
        XCTAssertNil(steps[7].repetition)
    }

    func testTimePhasesSwitchAndCountDown() {
        let sim = Sim(Plan(name: "T", items: [.phase(timePhase(30)), .phase(timePhase(20))]))
        sim.start()
        XCTAssertEqual(sim.engine.state, .running)
        sim.advance(60)

        XCTAssertEqual(sim.startedStepIndexes, [0, 1])
        XCTAssertEqual(sim.times(of: .timeWarning(seconds: 10)), [20, 40])
        XCTAssertEqual(sim.times(of: .countdown(3)), [27, 47])
        XCTAssertEqual(sim.times(of: .countdown(2)), [28, 48])
        XCTAssertEqual(sim.times(of: .countdown(1)), [29, 49])

        let secondStart = sim.log.first { entry in
            if case .phaseStarted(let step) = entry.event { return step.index == 1 }
            return false
        }
        XCTAssertEqual(secondStart?.t, 30)

        XCTAssertEqual(sim.engine.state, .finished)
        let summary = sim.summary
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.completed, true)
        XCTAssertEqual(summary?.totalSeconds ?? 0, 50, accuracy: 0.001)
        XCTAssertEqual(summary?.results.count, 2)
        XCTAssertEqual(summary?.results.first?.seconds ?? 0, 30, accuracy: 0.001)
    }

    func testDistancePhaseUsesDistance() {
        let sim = Sim(Plan(name: "D", items: [.phase(distancePhase(400)), .phase(timePhase(10))]))
        sim.start()
        sim.advance(100, speed: 4)

        XCTAssertEqual(sim.times(of: .halfwayDistance(remainingMeters: 200)), [50])
        XCTAssertEqual(sim.times(of: .distanceWarning(meters: 50)), [88])
        XCTAssertEqual(sim.startedStepIndexes, [0, 1])
        XCTAssertEqual(sim.engine.stepIndex, 1)
        // Bei Streckenphasen gibt es keinen 3-2-1-Countdown.
        XCTAssertTrue(sim.times(of: .countdown(3)).isEmpty)

        sim.advance(10, speed: 4)
        XCTAssertEqual(sim.times(of: .countdown(3)), [107])
        XCTAssertEqual(sim.engine.state, .finished)
        XCTAssertEqual(sim.summary?.totalMeters ?? 0, 440, accuracy: 0.001)
        XCTAssertEqual(sim.summary?.results.first?.meters ?? 0, 400, accuracy: 0.001)
    }

    func testHalfwayOfTimePhase() {
        let sim = Sim(Plan(name: "H", items: [.phase(timePhase(120))]))
        sim.start()
        sim.advance(70)
        XCTAssertEqual(sim.times(of: .halfwayTime(remainingSeconds: 60)), [60])
    }

    func testShortPhasesHaveNoHalfway() {
        let sim = Sim(Plan(name: "H", items: [.phase(timePhase(30)), .phase(distancePhase(200))]))
        sim.start()
        sim.advance(30)
        sim.advance(50, speed: 4)
        let halfway = sim.events.filter { event in
            switch event {
            case .halfwayTime, .halfwayDistance: return true
            default: return false
            }
        }
        XCTAssertTrue(halfway.isEmpty)
        XCTAssertEqual(sim.engine.state, .finished)
    }

    func testPauseDiscardsTimeAndDistance() {
        let sim = Sim(Plan(name: "P", items: [.phase(timePhase(60))]))
        sim.start()
        sim.advance(10, speed: 3)
        sim.record(sim.engine.pause())
        XCTAssertEqual(sim.engine.state, .paused)
        sim.advance(30, speed: 1)
        sim.record(sim.engine.resume(time: sim.time, distance: sim.distance))
        XCTAssertEqual(sim.engine.state, .running)
        sim.advance(10, speed: 3)

        XCTAssertEqual(sim.engine.phaseTime, 20, accuracy: 0.001)
        XCTAssertEqual(sim.engine.totalTime, 20, accuracy: 0.001)
        XCTAssertEqual(sim.engine.totalDistance, 60, accuracy: 0.001)
        XCTAssertEqual(sim.times(of: .paused), [10])
        XCTAssertEqual(sim.times(of: .resumed), [40])
    }

    func testSkipAdvancesAndFinishes() {
        let sim = Sim(Plan(name: "S", items: [
            .phase(timePhase(60)), .phase(timePhase(60)), .phase(timePhase(60))
        ]))
        sim.start()
        sim.advance(5)
        sim.record(sim.engine.skip())
        XCTAssertEqual(sim.engine.stepIndex, 1)
        XCTAssertEqual(sim.engine.phaseTime, 0, accuracy: 0.001)
        sim.record(sim.engine.skip())
        sim.record(sim.engine.skip())

        XCTAssertEqual(sim.startedStepIndexes, [0, 1, 2])
        XCTAssertEqual(sim.engine.state, .finished)
        XCTAssertEqual(sim.summary?.completed, true)
        XCTAssertEqual(sim.summary?.results.count, 3)
        XCTAssertEqual(sim.summary?.results.allSatisfy { $0.skipped }, true)
    }

    func testStopEndsEarly() {
        let sim = Sim(Plan(name: "S", items: [.phase(timePhase(60)), .phase(timePhase(60))]))
        sim.start()
        sim.advance(5, speed: 3)
        sim.record(sim.engine.stop())

        XCTAssertEqual(sim.engine.state, .finished)
        XCTAssertEqual(sim.summary?.completed, false)
        XCTAssertEqual(sim.summary?.results.count, 1)
        XCTAssertEqual(sim.summary?.totalSeconds ?? 0, 5, accuracy: 0.001)
        XCTAssertNil(sim.engine.currentStep)
        // Weitere Updates ändern nichts mehr.
        sim.advance(5, speed: 3)
        XCTAssertEqual(sim.engine.totalTime, 5, accuracy: 0.001)
    }

    func testPaceHintsRespectDelayAndInterval() {
        let range = PaceRange(fastSecPerKm: 270, slowSecPerKm: 280)
        let sim = Sim(Plan(name: "Pace", items: [.phase(timePhase(600, pace: range))]))
        sim.start()

        // Zu langsam: Hinweis „schneller“ erst nach 20 s, dann alle 30 s.
        sim.advance(80, pace: 300)
        XCTAssertEqual(sim.times(of: .paceHint(.faster)), [20, 50, 80])

        // Wieder im Bereich: genau eine Rückmeldung.
        sim.advance(75, pace: 275)
        XCTAssertEqual(sim.times(of: .paceHint(.onTarget)), [90])

        // Zu schnell: „langsamer“.
        sim.advance(40, pace: 250)
        XCTAssertEqual(sim.times(of: .paceHint(.slower)).first, 156)
        XCTAssertEqual(sim.times(of: .paceHint(.slower)).count, 2)
    }

    func testNoPaceHintsWithoutTargetOrPace() {
        let range = PaceRange(fastSecPerKm: 270, slowSecPerKm: 280)
        let sim = Sim(Plan(name: "Pace", items: [
            .phase(timePhase(100)),
            .phase(timePhase(100, pace: range))
        ]))
        sim.start()
        sim.advance(100, pace: 400)
        sim.advance(80, pace: nil)
        let hints = sim.events.filter { event in
            if case .paceHint = event { return true }
            return false
        }
        XCTAssertTrue(hints.isEmpty)
    }

    func testOvershootCarriesIntoNextPhase() {
        let sim = Sim(Plan(name: "C", items: [.phase(timePhase(10)), .phase(timePhase(10))]))
        sim.start()
        sim.time += 10.5
        sim.record(sim.engine.update(time: sim.time, distance: sim.distance))
        XCTAssertEqual(sim.engine.stepIndex, 1)
        XCTAssertEqual(sim.engine.phaseTime, 0.5, accuracy: 0.001)
        XCTAssertEqual(sim.engine.results.first?.seconds ?? 0, 10, accuracy: 0.001)
    }

    func testEmptyPlanFinishesImmediately() {
        let sim = Sim(Plan(name: "Leer"))
        sim.start()
        XCTAssertEqual(sim.engine.state, .finished)
        XCTAssertEqual(sim.summary?.stepCount, 0)
    }

    func testProgressValues() {
        let sim = Sim(Plan(name: "F", items: [.phase(timePhase(40)), .phase(distancePhase(100))]))
        XCTAssertEqual(sim.engine.planProgress, 0, accuracy: 0.001)
        sim.start()
        sim.advance(10)
        XCTAssertEqual(sim.engine.phaseProgress, 0.25, accuracy: 0.001)
        XCTAssertEqual(sim.engine.planProgress, 0.125, accuracy: 0.001)
        XCTAssertEqual(sim.engine.remainingTime ?? 0, 30, accuracy: 0.001)
        XCTAssertNil(sim.engine.remainingDistance)
        sim.advance(30)
        sim.advance(10, speed: 5)
        XCTAssertEqual(sim.engine.remainingDistance ?? 0, 50, accuracy: 0.001)
        XCTAssertEqual(sim.engine.planProgress, 0.75, accuracy: 0.001)
    }
}
