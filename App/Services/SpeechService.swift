import AVFoundation
import Foundation
import IntervalCore

/// Sprachausgabe mit AVSpeechSynthesizer.
///
/// Die Audio-Session ist immer mischbar: Andere Apps (Musik, Strava) werden nie gestoppt,
/// sondern je nach Einstellung nur während der Ansage leiser gestellt. Nach der Ansage wird
/// die Session wieder freigegeben, damit die anderen Apps zur normalen Lautstärke zurückkehren.
final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {

    struct Config: Equatable {
        var duckOthers = true
        var volume: Float = 1.0
        var rate: Float = AVSpeechUtteranceDefaultSpeechRate
        var voiceIdentifier = ""
    }

    var config = Config()

    private let synthesizer = AVSpeechSynthesizer()
    /// Ansagen, die gerade gesprochen werden oder in der Warteschlange stehen.
    private var live = Set<ObjectIdentifier>()
    private var deactivationToken = 0
    private var configuredDuck: Bool?
    private var cachedVoice: AVSpeechSynthesisVoice?
    private var cachedVoiceIdentifier: String?

    /// So lange bleibt die Session nach der letzten Ansage aktiv (überbrückt den Countdown).
    private let deactivationDelay: TimeInterval = 1.3

    override init() {
        super.init()
        synthesizer.delegate = self
        synthesizer.usesApplicationAudioSession = true
    }

    // MARK: - Sprechen

    func speak(_ announcement: Announcement) {
        let text = announcement.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        switch announcement.priority {
        case .low:
            if !live.isEmpty || synthesizer.isSpeaking { return }
        case .normal:
            break
        case .high:
            if !live.isEmpty || synthesizer.isSpeaking {
                live.removeAll()
                synthesizer.stopSpeaking(at: .immediate)
            }
        }

        activateSession()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = resolvedVoice()
        utterance.rate = min(max(config.rate, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
        utterance.volume = min(max(config.volume, 0.05), 1.0)

        live.insert(ObjectIdentifier(utterance))
        deactivationToken += 1
        synthesizer.speak(utterance)
    }

    /// Bricht alle Ansagen ab.
    func stopAll() {
        live.removeAll()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        scheduleDeactivation()
    }

    // MARK: - Audio-Session

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            if configuredDuck != config.duckOthers {
                let options: AVAudioSession.CategoryOptions = config.duckOthers
                    ? [.mixWithOthers, .duckOthers]
                    : [.mixWithOthers]
                try session.setCategory(.playback, mode: .voicePrompt, options: options)
                configuredDuck = config.duckOthers
            }
            try session.setActive(true)
        } catch {
            // Ohne aktive Session spricht der Synthesizer trotzdem, nur ohne Absenken.
            configuredDuck = nil
        }
    }

    private func scheduleDeactivation() {
        deactivationToken += 1
        let token = deactivationToken
        DispatchQueue.main.asyncAfter(deadline: .now() + deactivationDelay) { [weak self] in
            guard let self = self else { return }
            guard token == self.deactivationToken, self.live.isEmpty, !self.synthesizer.isSpeaking else { return }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func utteranceEnded(_ id: ObjectIdentifier) {
        live.remove(id)
        if live.isEmpty {
            scheduleDeactivation()
        }
    }

    // MARK: - Stimmen

    /// Alle installierten deutschen Stimmen, die besten zuerst.
    static func germanVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("de") }
            .sorted { a, b in
                if a.quality.rawValue != b.quality.rawValue {
                    return a.quality.rawValue > b.quality.rawValue
                }
                if a.language != b.language {
                    return a.language == "de-DE"
                }
                return a.name < b.name
            }
    }

    static func qualityLabel(_ voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .premium: return "Premium"
        case .enhanced: return "Erweitert"
        default: return "Standard"
        }
    }

    private func resolvedVoice() -> AVSpeechSynthesisVoice? {
        if cachedVoiceIdentifier == config.voiceIdentifier, let voice = cachedVoice {
            return voice
        }
        var voice: AVSpeechSynthesisVoice?
        if !config.voiceIdentifier.isEmpty {
            voice = AVSpeechSynthesisVoice(identifier: config.voiceIdentifier)
        }
        if voice == nil {
            // Automatisch: eine hochwertige deutsche Stimme, sonst die Standardstimme.
            voice = Self.germanVoices().first { $0.quality != .default && $0.language == "de-DE" }
        }
        if voice == nil {
            voice = AVSpeechSynthesisVoice(language: "de-DE")
        }
        cachedVoice = voice
        cachedVoiceIdentifier = config.voiceIdentifier
        return voice
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        DispatchQueue.main.async { [weak self] in
            self?.utteranceEnded(id)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        DispatchQueue.main.async { [weak self] in
            self?.utteranceEnded(id)
        }
    }
}
