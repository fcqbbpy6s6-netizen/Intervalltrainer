import IntervalCore
import SwiftUI

/// Editor für eine einzelne Phase.
struct PhaseEditorView: View {
    @Binding var phase: Phase

    @State private var lastSeconds = 60
    @State private var lastMeters = 400
    @FocusState private var metersFocused: Bool

    private let distancePresets = [100, 200, 400, 800, 1000, 2000]

    var body: some View {
        Form {
            Section("Typ") {
                Picker("Typ", selection: $phase.kind) {
                    ForEach(PhaseKind.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                TextField("Eigener Name (optional)", text: nameBinding)
            }

            Section("Dauer") {
                Picker("Dauer als", selection: goalIsTime) {
                    Text("Zeit").tag(true)
                    Text("Strecke").tag(false)
                }
                .pickerStyle(.segmented)

                if phase.goal.isTime {
                    MinSecPicker(title: "Zeit", totalSeconds: secondsBinding, minuteRange: 0...120)
                } else {
                    LabeledContent("Strecke in Metern") {
                        TextField("Meter", value: metersBinding, format: .number.grouping(.never))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($metersFocused)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(distancePresets, id: \.self) { meters in
                                Button(RunFormat.distance(meters: meters)) {
                                    metersFocused = false
                                    metersBinding.wrappedValue = meters
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }

            Section {
                Toggle("Ziel-Pace vorgeben", isOn: paceEnabled)
                if phase.targetPace != nil {
                    MinSecPicker(title: "Von (schnell)", totalSeconds: paceFast, minuteRange: 2...15)
                    MinSecPicker(title: "Bis (langsam)", totalSeconds: paceSlow, minuteRange: 2...15)
                }
            } header: {
                Text("Ziel-Pace pro Kilometer")
            } footer: {
                Text("Liegt deine Pace außerhalb des Bereichs, sagt die App „schneller“ oder „langsamer“ an.")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(phase.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") {
                    metersFocused = false
                }
            }
        }
    }

    // MARK: - Bindings

    private var nameBinding: Binding<String> {
        Binding(
            get: { phase.customName ?? "" },
            set: { phase.customName = $0.isEmpty ? nil : $0 }
        )
    }

    private var goalIsTime: Binding<Bool> {
        Binding(
            get: { phase.goal.isTime },
            set: { wantsTime in
                switch phase.goal {
                case .time(let seconds):
                    if !wantsTime {
                        lastSeconds = seconds
                        phase.goal = .distance(meters: lastMeters)
                    }
                case .distance(let meters):
                    if wantsTime {
                        lastMeters = meters
                        phase.goal = .time(seconds: lastSeconds)
                    }
                }
            }
        )
    }

    private var secondsBinding: Binding<Int> {
        Binding(
            get: {
                if case .time(let seconds) = phase.goal { return seconds }
                return lastSeconds
            },
            set: { phase.goal = .time(seconds: max(5, $0)) }
        )
    }

    private var metersBinding: Binding<Int> {
        Binding(
            get: {
                if case .distance(let meters) = phase.goal { return meters }
                return lastMeters
            },
            set: { phase.goal = .distance(meters: min(max(10, $0), 100_000)) }
        )
    }

    private var paceEnabled: Binding<Bool> {
        Binding(
            get: { phase.targetPace != nil },
            set: { enabled in
                if enabled {
                    if phase.targetPace == nil {
                        phase.targetPace = PaceRange(fastSecPerKm: 285, slowSecPerKm: 300)
                    }
                } else {
                    phase.targetPace = nil
                }
            }
        )
    }

    private var paceFast: Binding<Int> {
        Binding(
            get: { phase.targetPace?.fastSecPerKm ?? 285 },
            set: { value in
                guard var pace = phase.targetPace else { return }
                pace.fastSecPerKm = max(60, value)
                if pace.slowSecPerKm < pace.fastSecPerKm {
                    pace.slowSecPerKm = pace.fastSecPerKm
                }
                phase.targetPace = pace
            }
        )
    }

    private var paceSlow: Binding<Int> {
        Binding(
            get: { phase.targetPace?.slowSecPerKm ?? 300 },
            set: { value in
                guard var pace = phase.targetPace else { return }
                pace.slowSecPerKm = max(60, value)
                if pace.fastSecPerKm > pace.slowSecPerKm {
                    pace.fastSecPerKm = pace.slowSecPerKm
                }
                phase.targetPace = pace
            }
        )
    }
}
