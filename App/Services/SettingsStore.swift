import AVFoundation
import Combine
import Foundation
import IntervalCore

/// Verhalten gegenüber dem Audio anderer Apps.
enum AudioMode: String, CaseIterable, Identifiable {
    /// Andere Apps werden während der Ansage leiser.
    case duck
    /// Andere Apps laufen unverändert weiter, die Ansage wird nur dazugemischt.
    case mix

    var id: String { rawValue }

    var title: String {
        switch self {
        case .duck: return "Leiser stellen"
        case .mix: return "Nur mischen"
        }
    }
}

/// Einstellungen, gespeichert in UserDefaults.
final class SettingsStore: ObservableObject {
    private enum Keys {
        static let audioMode = "audioMode"
        static let speechVolume = "speechVolume"
        static let speechRate = "speechRate"
        static let voiceIdentifier = "voiceIdentifier"
        static let announcePhaseChanges = "announcePhaseChanges"
        static let announceCountdown = "announceCountdown"
        static let announceHalfway = "announceHalfway"
        static let announcePaceHints = "announcePaceHints"
        static let announceSummary = "announceSummary"
        static let paceHintInterval = "paceHintInterval"
        static let keepScreenOn = "keepScreenOn"
    }

    static let rateRange: ClosedRange<Double> = 0.35...0.65
    static let paceHintIntervalRange: ClosedRange<Int> = 15...120

    private let defaults: UserDefaults

    @Published var audioMode: AudioMode {
        didSet { defaults.set(audioMode.rawValue, forKey: Keys.audioMode) }
    }
    @Published var speechVolume: Double {
        didSet { defaults.set(speechVolume, forKey: Keys.speechVolume) }
    }
    @Published var speechRate: Double {
        didSet { defaults.set(speechRate, forKey: Keys.speechRate) }
    }
    /// Leer = automatisch die beste deutsche Stimme.
    @Published var voiceIdentifier: String {
        didSet { defaults.set(voiceIdentifier, forKey: Keys.voiceIdentifier) }
    }
    @Published var announcePhaseChanges: Bool {
        didSet { defaults.set(announcePhaseChanges, forKey: Keys.announcePhaseChanges) }
    }
    @Published var announceCountdown: Bool {
        didSet { defaults.set(announceCountdown, forKey: Keys.announceCountdown) }
    }
    @Published var announceHalfway: Bool {
        didSet { defaults.set(announceHalfway, forKey: Keys.announceHalfway) }
    }
    @Published var announcePaceHints: Bool {
        didSet { defaults.set(announcePaceHints, forKey: Keys.announcePaceHints) }
    }
    @Published var announceSummary: Bool {
        didSet { defaults.set(announceSummary, forKey: Keys.announceSummary) }
    }
    /// Mindestabstand zwischen Pace-Hinweisen in Sekunden.
    @Published var paceHintInterval: Int {
        didSet { defaults.set(paceHintInterval, forKey: Keys.paceHintInterval) }
    }
    @Published var keepScreenOn: Bool {
        didSet { defaults.set(keepScreenOn, forKey: Keys.keepScreenOn) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.audioMode = AudioMode(rawValue: defaults.string(forKey: Keys.audioMode) ?? "") ?? .duck
        self.speechVolume = Self.double(defaults, Keys.speechVolume, fallback: 1.0, range: 0.1...1.0)
        self.speechRate = Self.double(
            defaults,
            Keys.speechRate,
            fallback: Double(AVSpeechUtteranceDefaultSpeechRate),
            range: Self.rateRange
        )
        self.voiceIdentifier = defaults.string(forKey: Keys.voiceIdentifier) ?? ""
        self.announcePhaseChanges = Self.bool(defaults, Keys.announcePhaseChanges, fallback: true)
        self.announceCountdown = Self.bool(defaults, Keys.announceCountdown, fallback: true)
        self.announceHalfway = Self.bool(defaults, Keys.announceHalfway, fallback: true)
        self.announcePaceHints = Self.bool(defaults, Keys.announcePaceHints, fallback: true)
        self.announceSummary = Self.bool(defaults, Keys.announceSummary, fallback: true)
        let interval = (defaults.object(forKey: Keys.paceHintInterval) as? Int) ?? 30
        self.paceHintInterval = min(max(interval, Self.paceHintIntervalRange.lowerBound), Self.paceHintIntervalRange.upperBound)
        self.keepScreenOn = Self.bool(defaults, Keys.keepScreenOn, fallback: true)
    }

    private static func bool(_ defaults: UserDefaults, _ key: String, fallback: Bool) -> Bool {
        (defaults.object(forKey: key) as? Bool) ?? fallback
    }

    private static func double(
        _ defaults: UserDefaults,
        _ key: String,
        fallback: Double,
        range: ClosedRange<Double>
    ) -> Double {
        let value = (defaults.object(forKey: key) as? Double) ?? fallback
        return min(max(value, range.lowerBound), range.upperBound)
    }

    // MARK: - Abgeleitete Werte

    var announcementSettings: AnnouncementSettings {
        var result = AnnouncementSettings()
        result.phaseChanges = announcePhaseChanges
        result.countdown = announceCountdown
        result.halfway = announceHalfway
        result.paceHints = announcePaceHints
        result.summary = announceSummary
        return result
    }

    var speechConfig: SpeechService.Config {
        SpeechService.Config(
            duckOthers: audioMode == .duck,
            volume: Float(speechVolume),
            rate: Float(speechRate),
            voiceIdentifier: voiceIdentifier
        )
    }
}
