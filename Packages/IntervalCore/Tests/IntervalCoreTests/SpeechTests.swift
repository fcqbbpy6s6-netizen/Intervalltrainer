import XCTest
@testable import IntervalCore

final class SpeechTests: XCTestCase {

    func testSpellNumbers() {
        XCTAssertEqual(GermanSpeech.spell(0), "null")
        XCTAssertEqual(GermanSpeech.spell(1), "eins")
        XCTAssertEqual(GermanSpeech.spell(7), "sieben")
        XCTAssertEqual(GermanSpeech.spell(11), "elf")
        XCTAssertEqual(GermanSpeech.spell(16), "sechzehn")
        XCTAssertEqual(GermanSpeech.spell(17), "siebzehn")
        XCTAssertEqual(GermanSpeech.spell(21), "einundzwanzig")
        XCTAssertEqual(GermanSpeech.spell(30), "dreißig")
        XCTAssertEqual(GermanSpeech.spell(70), "siebzig")
        XCTAssertEqual(GermanSpeech.spell(99), "neunundneunzig")
        XCTAssertEqual(GermanSpeech.spell(100), "einhundert")
        XCTAssertEqual(GermanSpeech.spell(101), "einhunderteins")
        XCTAssertEqual(GermanSpeech.spell(400), "vierhundert")
        XCTAssertEqual(GermanSpeech.spell(1000), "eintausend")
        XCTAssertEqual(GermanSpeech.spell(1250), "eintausendzweihundertfünfzig")
        XCTAssertEqual(GermanSpeech.spell(21000), "einundzwanzigtausend")
    }

    func testDurations() {
        XCTAssertEqual(GermanSpeech.duration(seconds: 1), "eine Sekunde")
        XCTAssertEqual(GermanSpeech.duration(seconds: 10), "zehn Sekunden")
        XCTAssertEqual(GermanSpeech.duration(seconds: 30), "dreißig Sekunden")
        XCTAssertEqual(GermanSpeech.duration(seconds: 60), "eine Minute")
        XCTAssertEqual(GermanSpeech.duration(seconds: 90), "eine Minute dreißig")
        XCTAssertEqual(GermanSpeech.duration(seconds: 270), "vier Minuten dreißig")
        XCTAssertEqual(GermanSpeech.duration(seconds: 600), "zehn Minuten")
        XCTAssertEqual(GermanSpeech.duration(seconds: 3900), "eine Stunde fünf Minuten")
    }

    func testDistances() {
        XCTAssertEqual(GermanSpeech.distance(meters: 1), "ein Meter")
        XCTAssertEqual(GermanSpeech.distance(meters: 50), "fünfzig Meter")
        XCTAssertEqual(GermanSpeech.distance(meters: 400), "vierhundert Meter")
        XCTAssertEqual(GermanSpeech.distance(meters: 1000), "ein Kilometer")
        XCTAssertEqual(GermanSpeech.distance(meters: 1500), "eins Komma fünf Kilometer")
        XCTAssertEqual(GermanSpeech.distance(meters: 5000), "fünf Kilometer")
        XCTAssertEqual(GermanSpeech.kilometers(meters: 5230), "fünf Komma zwei drei Kilometer")
        XCTAssertEqual(GermanSpeech.kilometers(meters: 10004), "zehn Kilometer")
    }

    func testPaceRange() {
        XCTAssertEqual(
            GermanSpeech.paceRange(PaceRange(fastSecPerKm: 270, slowSecPerKm: 270)),
            "vier Minuten dreißig"
        )
        XCTAssertEqual(
            GermanSpeech.paceRange(PaceRange(fastSecPerKm: 280, slowSecPerKm: 270)),
            "vier Minuten dreißig bis vier Minuten vierzig"
        )
    }

    func testIntervalAnnouncement() {
        let phase = Phase(
            kind: .work,
            goal: .distance(meters: 400),
            targetPace: PaceRange(fastSecPerKm: 270, slowSecPerKm: 270)
        )
        let step = WorkoutStep(index: 5, phase: phase, repetition: 3, repetitionCount: 6)
        XCTAssertEqual(
            AnnouncementBuilder.phaseText(step),
            "Intervall drei von sechs. Vierhundert Meter schnell. Ziel-Pace vier Minuten dreißig."
        )
    }

    func testOtherPhaseAnnouncements() {
        let recovery = WorkoutStep(
            index: 2,
            phase: Phase(kind: .recovery, goal: .time(seconds: 90)),
            repetition: 1,
            repetitionCount: 8
        )
        XCTAssertEqual(AnnouncementBuilder.phaseText(recovery), "Eine Minute dreißig Trabpause.")

        let warmup = WorkoutStep(index: 0, phase: Phase(kind: .warmup, goal: .time(seconds: 600)))
        XCTAssertEqual(AnnouncementBuilder.phaseText(warmup), "Einlaufen. Zehn Minuten.")

        let cooldown = WorkoutStep(index: 9, phase: Phase(kind: .cooldown, goal: .distance(meters: 1000)))
        XCTAssertEqual(AnnouncementBuilder.phaseText(cooldown), "Auslaufen. Ein Kilometer.")

        let custom = WorkoutStep(
            index: 3,
            phase: Phase(kind: .work, customName: "Tempo", goal: .time(seconds: 600))
        )
        XCTAssertEqual(AnnouncementBuilder.phaseText(custom), "Tempo. Zehn Minuten.")
    }

    func testEventAnnouncements() {
        XCTAssertEqual(
            AnnouncementBuilder.announcement(for: .countdown(3)),
            Announcement(text: "drei", priority: .high)
        )
        XCTAssertEqual(
            AnnouncementBuilder.announcement(for: .timeWarning(seconds: 10))?.text,
            "Noch zehn Sekunden."
        )
        XCTAssertEqual(
            AnnouncementBuilder.announcement(for: .distanceWarning(meters: 50))?.text,
            "Noch fünfzig Meter."
        )
        XCTAssertEqual(
            AnnouncementBuilder.announcement(for: .halfwayTime(remainingSeconds: 120))?.text,
            "Halbzeit. Noch zwei Minuten."
        )
        XCTAssertEqual(
            AnnouncementBuilder.announcement(for: .halfwayDistance(remainingMeters: 200))?.text,
            "Halbzeit. Noch zweihundert Meter."
        )
        XCTAssertEqual(
            AnnouncementBuilder.announcement(for: .paceHint(.faster)),
            Announcement(text: "Schneller.", priority: .low)
        )
        XCTAssertEqual(AnnouncementBuilder.announcement(for: .paceHint(.slower))?.text, "Langsamer.")
    }

    func testSummaryAnnouncement() {
        let summary = WorkoutSummary(
            totalSeconds: 1690,
            totalMeters: 5230,
            completed: true,
            stepCount: 4,
            results: []
        )
        XCTAssertEqual(
            AnnouncementBuilder.summaryText(summary),
            "Training beendet. Fünf Komma zwei drei Kilometer in achtundzwanzig Minuten zehn. "
                + "Durchschnitts-Pace fünf Minuten dreiundzwanzig pro Kilometer."
        )

        let noDistance = WorkoutSummary(totalSeconds: 600, totalMeters: 0, completed: true, stepCount: 1, results: [])
        XCTAssertEqual(AnnouncementBuilder.summaryText(noDistance), "Training beendet. Dauer zehn Minuten.")
    }

    func testSettingsDisableAnnouncements() {
        var settings = AnnouncementSettings()
        settings.countdown = false
        settings.halfway = false
        settings.paceHints = false
        XCTAssertNil(AnnouncementBuilder.announcement(for: .countdown(3), settings: settings))
        XCTAssertNil(AnnouncementBuilder.announcement(for: .timeWarning(seconds: 10), settings: settings))
        XCTAssertNil(AnnouncementBuilder.announcement(for: .halfwayTime(remainingSeconds: 60), settings: settings))
        XCTAssertNil(AnnouncementBuilder.announcement(for: .paceHint(.faster), settings: settings))
        XCTAssertNotNil(AnnouncementBuilder.announcement(for: .paused, settings: settings))

        settings.summary = false
        let summary = WorkoutSummary(totalSeconds: 600, totalMeters: 2000, completed: true, stepCount: 1, results: [])
        XCTAssertEqual(
            AnnouncementBuilder.announcement(for: .finished(summary), settings: settings)?.text,
            "Training beendet."
        )
    }
}
