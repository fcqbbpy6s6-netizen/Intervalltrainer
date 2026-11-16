import CoreLocation
import IntervalCore
import SwiftUI

/// Große Anzeige während des Laufs.
struct RunView: View {
    @StateObject private var session: WorkoutSession
    @Environment(\.dismiss) private var dismiss
    @State private var confirmStop = false

    init(plan: Plan, speech: SpeechService, location: LocationService, settings: SettingsStore) {
        _session = StateObject(wrappedValue: WorkoutSession(
            plan: plan,
            speech: speech,
            location: location,
            settings: settings
        ))
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            if let summary = session.summary {
                SummaryView(summary: summary, planName: session.plan.name) {
                    dismiss()
                }
            } else {
                runContent
            }
        }
        .onAppear {
            session.prepare()
        }
        .onDisappear {
            session.teardown()
        }
        .confirmationDialog("Training wirklich beenden?", isPresented: $confirmStop, titleVisibility: .visible) {
            Button("Training beenden", role: .destructive) {
                session.stop()
            }
            Button("Weiterlaufen", role: .cancel) {}
        }
    }

    // MARK: - Aufbau

    private var runContent: some View {
        let display = session.display
        let kind = display.step?.phase.kind ?? .warmup
        return VStack(spacing: 10) {
            header(display)
            if locationBlocked {
                locationWarning
            }
            Spacer(minLength: 0)

            Text(display.step?.phase.displayName ?? session.plan.name)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(kind.color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(subtitle(display))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(mainValue(display))
                .font(.system(size: 120, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .padding(.horizontal, 4)

            Text(mainLabel(display))
                .font(.headline)
                .foregroundStyle(.secondary)

            ProgressView(value: display.phaseProgress)
                .tint(kind.color)
                .scaleEffect(x: 1, y: 2.5, anchor: .center)
                .padding(.vertical, 6)

            HStack(spacing: 12) {
                metric("Pace", paceText(display), color: paceColor(display))
                metric("Ziel-Pace", targetPaceText(display), color: .primary)
            }
            HStack(spacing: 12) {
                metric("Gesamtzeit", RunFormat.clock(display.totalSeconds), color: .primary)
                metric("Distanz", RunFormat.kilometers(display.totalMeters) + " km", color: .primary)
            }

            Spacer(minLength: 0)
            planProgress(display)
            buttons(display)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func header(_ display: RunDisplay) -> some View {
        HStack {
            Label(gpsText, systemImage: "location.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(gpsColor)
            Spacer()
            if display.state == .paused {
                Text("PAUSIERT")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.top, 8)
    }

    private var locationWarning: some View {
        VStack(spacing: 6) {
            Text("Kein Standortzugriff. Strecke und Pace können nicht gemessen werden, Streckenphasen enden nicht von selbst.")
                .font(.footnote)
                .multilineTextAlignment(.center)
            Button("iOS-Einstellungen öffnen") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.footnote.weight(.semibold))
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func metric(_ title: String, _ value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func planProgress(_ display: RunDisplay) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(stepText(display))
                Spacer()
                Text(nextText(display))
                    .lineLimit(1)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            ProgressView(value: display.planProgress)
                .tint(.accentColor)
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func buttons(_ display: RunDisplay) -> some View {
        switch display.state {
        case .ready:
            VStack(spacing: 10) {
                Button {
                    session.start()
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(BigButtonStyle(color: .green, minHeight: 84))

                Button("Schließen") {
                    dismiss()
                }
                .font(.title3)
                .padding(.vertical, 6)
            }
        case .running, .paused:
            VStack(spacing: 10) {
                Button {
                    session.togglePause()
                } label: {
                    if display.state == .paused {
                        Label("Fortsetzen", systemImage: "play.fill")
                    } else {
                        Label("Pause", systemImage: "pause.fill")
                    }
                }
                .buttonStyle(BigButtonStyle(color: display.state == .paused ? .green : .orange, minHeight: 84))

                HStack(spacing: 10) {
                    Button {
                        session.skip()
                    } label: {
                        Label("Überspringen", systemImage: "forward.end.fill")
                    }
                    .buttonStyle(BigButtonStyle(color: .blue))

                    Button {
                        confirmStop = true
                    } label: {
                        Label("Beenden", systemImage: "stop.fill")
                    }
                    .buttonStyle(BigButtonStyle(color: .red))
                }
            }
        case .finished:
            Button("Schließen") {
                dismiss()
            }
            .buttonStyle(BigButtonStyle(color: .gray))
        }
    }

    // MARK: - Texte

    private var locationBlocked: Bool {
        session.authorization == .denied || session.authorization == .restricted
    }

    private var gpsText: String {
        if locationBlocked {
            return "GPS aus"
        }
        guard let accuracy = session.gpsAccuracy else {
            return "GPS wird gesucht"
        }
        if accuracy <= 10 {
            return "GPS gut (±\(accuracy) m)"
        }
        if accuracy <= 25 {
            return "GPS mittel (±\(accuracy) m)"
        }
        return "GPS schwach (±\(accuracy) m)"
    }

    private var gpsColor: Color {
        if locationBlocked {
            return .red
        }
        guard let accuracy = session.gpsAccuracy else {
            return .secondary
        }
        if accuracy <= 10 {
            return .green
        }
        if accuracy <= 25 {
            return .orange
        }
        return .red
    }

    private func subtitle(_ display: RunDisplay) -> String {
        guard let step = display.step else { return " " }
        if let repetition = step.repetition, let count = step.repetitionCount {
            if step.phase.kind == .work {
                return "Intervall \(repetition) von \(count)"
            }
            return "Runde \(repetition) von \(count)"
        }
        return step.phase.trimmedCustomName == nil ? " " : step.phase.kind.displayName
    }

    private func mainValue(_ display: RunDisplay) -> String {
        if let seconds = display.remainingSeconds {
            return RunFormat.clock(seconds)
        }
        if let meters = display.remainingMeters {
            return meters >= 1000 ? RunFormat.kilometers(Double(meters)) : "\(meters)"
        }
        return "–"
    }

    private func mainLabel(_ display: RunDisplay) -> String {
        if display.remainingSeconds != nil {
            return display.state == .ready ? "Dauer der ersten Phase" : "Restzeit"
        }
        if let meters = display.remainingMeters {
            let unit = meters >= 1000 ? "Kilometer" : "Meter"
            return display.state == .ready ? "\(unit) in der ersten Phase" : "\(unit) Reststrecke"
        }
        return " "
    }

    private func paceText(_ display: RunDisplay) -> String {
        guard let pace = display.paceSecPerKm else { return "–:––" }
        return RunFormat.pace(pace)
    }

    private func paceColor(_ display: RunDisplay) -> Color {
        guard let pace = display.paceSecPerKm, let target = display.step?.phase.targetPace else {
            return .primary
        }
        if pace < target.fastSecPerKm || pace > target.slowSecPerKm {
            return .orange
        }
        return .green
    }

    private func targetPaceText(_ display: RunDisplay) -> String {
        guard let target = display.step?.phase.targetPace else { return "–" }
        if target.fastSecPerKm == target.slowSecPerKm {
            return RunFormat.pace(target.fastSecPerKm)
        }
        return RunFormat.pace(target.fastSecPerKm) + "–" + RunFormat.pace(target.slowSecPerKm)
    }

    private func stepText(_ display: RunDisplay) -> String {
        guard let step = display.step else { return "" }
        return "Schritt \(step.index + 1) von \(display.stepCount)"
    }

    private func nextText(_ display: RunDisplay) -> String {
        guard let next = display.nextStep else { return "Letzte Phase" }
        return "Danach: \(next.phase.displayName) \(RunFormat.goal(next.phase.goal))"
    }
}

/// Zusammenfassung nach dem Lauf.
struct SummaryView: View {
    let summary: WorkoutSummary
    let planName: String
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    VStack(spacing: 6) {
                        Text(summary.completed ? "Training beendet" : "Training abgebrochen")
                            .font(.title.weight(.bold))
                        Text(planName)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("Gesamt") {
                    LabeledContent("Zeit", value: RunFormat.clock(Int(summary.totalSeconds.rounded())))
                    LabeledContent("Distanz", value: RunFormat.kilometers(summary.totalMeters) + " km")
                    LabeledContent("Durchschnitts-Pace", value: paceText(summary.averagePaceSecPerKm))
                }

                Section("Phasen") {
                    ForEach(summary.results) { result in
                        HStack(spacing: 12) {
                            Image(systemName: result.step.phase.kind.symbolName)
                                .foregroundStyle(result.step.phase.kind.color)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title(result))
                                Text(detail(result))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(paceText(result.paceSecPerKm))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Button("Fertig") {
                onClose()
            }
            .buttonStyle(BigButtonStyle(color: .green))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func paceText(_ pace: Double?) -> String {
        guard let pace = pace else { return "–" }
        return RunFormat.pace(Int(pace.rounded())) + " /km"
    }

    private func title(_ result: PhaseResult) -> String {
        var text = result.step.phase.displayName
        if let repetition = result.step.repetition, let count = result.step.repetitionCount {
            text += " \(repetition)/\(count)"
        }
        return text
    }

    private func detail(_ result: PhaseResult) -> String {
        var text = RunFormat.clock(Int(result.seconds.rounded()))
            + " · " + RunFormat.distance(meters: Int(result.meters.rounded()))
        if result.skipped {
            text += " · übersprungen"
        }
        return text
    }
}
