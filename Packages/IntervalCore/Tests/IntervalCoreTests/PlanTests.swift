import XCTest
@testable import IntervalCore

final class PlanTests: XCTestCase {

    func testSummaryOfTimeOnlyPlan() {
        let plan = Plan(name: "Zeit", items: [
            .phase(Phase(kind: .warmup, goal: .time(seconds: 600))),
            .block(RepeatBlock(repeatCount: 8, phases: [
                Phase(kind: .work, goal: .time(seconds: 60)),
                Phase(kind: .recovery, goal: .time(seconds: 90))
            ])),
            .phase(Phase(kind: .cooldown, goal: .time(seconds: 300)))
        ])
        let summary = plan.summary
        XCTAssertEqual(summary.stepCount, 18)
        XCTAssertEqual(summary.exactSeconds, 2100)
        XCTAssertNil(summary.exactMeters)
        XCTAssertNil(summary.estimatedMeters)
        XCTAssertEqual(summary.text, "Dauer 35:00")
    }

    func testSummaryOfDistanceOnlyPlan() {
        let pace = PaceRange(fastSecPerKm: 300, slowSecPerKm: 300)
        let plan = Plan(name: "Strecke", items: [
            .block(RepeatBlock(repeatCount: 5, phases: [
                Phase(kind: .work, goal: .distance(meters: 1000), targetPace: pace)
            ]))
        ])
        let summary = plan.summary
        XCTAssertEqual(summary.exactMeters, 5000)
        XCTAssertNil(summary.exactSeconds)
        XCTAssertEqual(summary.estimatedSeconds, 1500)
        XCTAssertEqual(summary.text, "Strecke 5 km · ca. 25:00")
    }

    func testSummaryOfMixedPlan() {
        let plan = Plan(name: "Gemischt", items: [
            .phase(Phase(kind: .warmup, goal: .time(seconds: 600))),
            .block(RepeatBlock(repeatCount: 6, phases: [
                Phase(kind: .work, goal: .distance(meters: 400)),
                Phase(kind: .recovery, goal: .distance(meters: 200))
            ]))
        ])
        let summary = plan.summary
        XCTAssertNil(summary.exactSeconds)
        XCTAssertNil(summary.exactMeters)
        XCTAssertEqual(summary.timedSeconds, 600)
        XCTAssertEqual(summary.distanceMeters, 3600)
        XCTAssertEqual(summary.text, "10:00 + 3,6 km")
    }

    func testEmptyPlanSummary() {
        XCTAssertEqual(Plan(name: "Leer").summary.text, "Noch keine Phasen")
    }

    func testFormats() {
        XCTAssertEqual(RunFormat.clock(0), "0:00")
        XCTAssertEqual(RunFormat.clock(270), "4:30")
        XCTAssertEqual(RunFormat.clock(3905), "1:05:05")
        XCTAssertEqual(RunFormat.distance(meters: 400), "400 m")
        XCTAssertEqual(RunFormat.distance(meters: 1000), "1 km")
        XCTAssertEqual(RunFormat.distance(meters: 1500), "1,5 km")
        XCTAssertEqual(RunFormat.distance(meters: 1250), "1,25 km")
        XCTAssertEqual(RunFormat.kilometers(5234), "5,23")
        XCTAssertEqual(RunFormat.kilometers(80), "0,08")
        XCTAssertEqual(RunFormat.paceRange(PaceRange(fastSecPerKm: 270, slowSecPerKm: 280)), "4:30–4:40 /km")
    }

    func testPaceRangeIsOrdered() {
        let range = PaceRange(fastSecPerKm: 300, slowSecPerKm: 270)
        XCTAssertEqual(range.fastSecPerKm, 270)
        XCTAssertEqual(range.slowSecPerKm, 300)
    }

    func testDuplicateGetsNewIDs() {
        let original = PlanTemplates.all()[0]
        let copy = original.duplicated()
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertEqual(copy.name, original.name + " (Kopie)")
        XCTAssertEqual(copy.items.count, original.items.count)
        let originalIDs = Set(original.flattened().map { $0.phase.id })
        let copyIDs = Set(copy.flattened().map { $0.phase.id })
        XCTAssertTrue(originalIDs.isDisjoint(with: copyIDs))
        XCTAssertEqual(copy.summary, original.summary)
    }

    func testPlansSurviveJSONRoundTrip() throws {
        let plans = PlanTemplates.all()
        XCTAssertFalse(plans.isEmpty)
        let data = try JSONEncoder().encode(plans)
        let decoded = try JSONDecoder().decode([Plan].self, from: data)
        XCTAssertEqual(decoded, plans)
    }

    func testTemplatesAreUsable() {
        for plan in PlanTemplates.all() {
            XCTAssertFalse(plan.name.isEmpty)
            XCTAssertGreaterThan(plan.flattened().count, 2)
        }
    }
}
