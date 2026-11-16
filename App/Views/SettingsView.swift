import AVFoundation
import IntervalCore
import SwiftUI

/// Einstellungen für Audio, Stimme, Ansagen und Anzeige.
struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var services: AppServices
    @Environment(\.dismiss) private var dismiss

    private struct VoiceOption: Identifiable {
        let id: String
        let label: String
    }

    @State private var voices: [VoiceOption] = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Andere Apps bei Ansagen", selection: $settings.audioMode) {
                        ForEach(AudioMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    VStack(alignment: .leading) {
                        Text("Lautstärke der Ansagen: \(Int((settings.speechVolume * 100).rounded())) %")
                        Slider(value: $settings.speechVolume, in: 0.1...1.0, step: 0.05)
                    }
                } header: {
                    Text("Audio")
                } footer: {
                    Text("Musik und Strava laufen immer weiter. Mit „Leiser stellen“ werden sie nur während einer Ansage abgesenkt.")
                }

                Section {
                    Picker("Stimme", selection: $settings.voiceIdentifier) {
                        Text("Automatisch").tag("")
                        ForEach(voices) { voice in
                            Text(voice.label).tag(voice.id)
                        }
                    }
                    VStack(alignment: .leading) {
                        Text("Sprechgeschwindigkeit: \(rateLabel)")
                        Slider(value: $settings.speechRate, in: SettingsStore.rateRange, step: 0.01)
                    }
                    Button("Stimme testen") {
                        testVoice()
                    }
                } header: {
                    Text("Stimme")
                } footer: {
                    Text("Bessere Stimmen lädst du in den iOS-Einstellungen unter Bedienungshilfen › Gesprochene Inhalte › Stimmen › Deutsch.")
                }

                Section {
                    Toggle("Phasenwechsel", isOn: $settings.announcePhaseChanges)
                    Toggle("Countdown vor Phasenende", isOn: $settings.announceCountdown)
                    Toggle("Halbzeit mit Restzeit oder Reststrecke", isOn: $settings.announceHalfway)
                    Toggle("Pace-Hinweise", isOn: $settings.announcePaceHints)
                    Stepper(value: $settings.paceHintInterval, in: SettingsStore.paceHintIntervalRange, step: 5) {
                        Text("Abstand der Pace-Hinweise: \(settings.paceHintInterval) s")
                    }
                    .disabled(!settings.announcePaceHints)
                    Toggle("Zusammenfassung am Ende", isOn: $settings.announceSummary)
                } header: {
                    Text("Ansagen")
                } footer: {
                    Text("Der Countdown umfasst „noch 10 Sekunden“, „3, 2, 1“ und bei Streckenphasen „noch 50 Meter“. Ein geänderter Abstand der Pace-Hinweise gilt ab dem nächsten Lauf.")
                }

                Section("Anzeige") {
                    Toggle("Bildschirm nicht sperren", isOn: $settings.keepScreenOn)
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadVoices()
            }
        }
    }

    private var rateLabel: String {
        let percent = Int((settings.speechRate / Double(AVSpeechUtteranceDefaultSpeechRate) * 100).rounded())
        return "\(percent) %"
    }

    private func loadVoices() {
        var options = SpeechService.germanVoices().map { voice -> VoiceOption in
            var label = "\(voice.name) (\(SpeechService.qualityLabel(voice)))"
            if voice.language != "de-DE" {
                label += " · \(voice.language)"
            }
            return VoiceOption(id: voice.identifier, label: label)
        }
        // Eine gespeicherte, aber nicht mehr installierte Stimme trotzdem anzeigen.
        let current = settings.voiceIdentifier
        if !current.isEmpty, !options.contains(where: { $0.id == current }) {
            options.append(VoiceOption(id: current, label: "Nicht mehr installiert"))
        }
        voices = options
    }

    private func testVoice() {
        services.speech.config = settings.speechConfig
        services.speech.speak(Announcement(
            text: "Intervall drei von sechs. Vierhundert Meter schnell. Ziel-Pace vier Minuten dreißig.",
            priority: .high
        ))
    }
}
