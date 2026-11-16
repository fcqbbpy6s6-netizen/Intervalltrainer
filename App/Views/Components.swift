import IntervalCore
import SwiftUI

extension PhaseKind {
    /// Farbe der Phase in Listen und in der Laufanzeige.
    var color: Color {
        switch self {
        case .warmup: return .blue
        case .work: return .red
        case .recovery: return .green
        case .cooldown: return .teal
        }
    }

    var symbolName: String {
        switch self {
        case .warmup: return "sunrise"
        case .work: return "bolt.fill"
        case .recovery: return "leaf"
        case .cooldown: return "sunset"
        }
    }
}

/// Eine Zeile mit Typ, Name, Dauer und Ziel-Pace einer Phase.
struct PhaseRowView: View {
    let phase: Phase

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: phase.kind.symbolName)
                .foregroundStyle(phase.kind.color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(phase.displayName)
                if let pace = phase.targetPace {
                    Text("Ziel-Pace " + RunFormat.paceRange(pace))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(RunFormat.goal(phase.goal))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

/// Ein Wiederholungsblock mit seinen Phasen.
struct BlockRowView: View {
    let block: RepeatBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(block.repeatCount)× wiederholen", systemImage: "repeat")
                .font(.subheadline.weight(.semibold))
            if block.phases.isEmpty {
                Text("Noch keine Phasen im Block")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(block.phases) { phase in
                PhaseRowView(phase: phase)
                    .padding(.leading, 12)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Zeile für einen Plan-Eintrag: Phase oder Block.
struct PlanItemRowView: View {
    let item: PlanItem

    var body: some View {
        switch item {
        case .phase(let phase):
            PhaseRowView(phase: phase)
        case .block(let block):
            BlockRowView(block: block)
        }
    }
}

/// Auswahl von Minuten und Sekunden über zwei Menüs.
struct MinSecPicker: View {
    let title: String
    @Binding var totalSeconds: Int
    var minuteRange: ClosedRange<Int> = 0...120
    var secondStep: Int = 5

    private var minutes: Int { max(0, totalSeconds) / 60 }
    private var seconds: Int { max(0, totalSeconds) % 60 }

    private var minuteOptions: [Int] {
        var options = Set(minuteRange)
        options.insert(minutes)
        return options.sorted()
    }

    private var secondOptions: [Int] {
        var options = Set(stride(from: 0, to: 60, by: max(1, secondStep)))
        options.insert(seconds)
        return options.sorted()
    }

    private var minuteBinding: Binding<Int> {
        Binding(
            get: { minutes },
            set: { totalSeconds = $0 * 60 + seconds }
        )
    }

    private var secondBinding: Binding<Int> {
        Binding(
            get: { seconds },
            set: { totalSeconds = minutes * 60 + $0 }
        )
    }

    var body: some View {
        HStack(spacing: 2) {
            Text(title)
            Spacer()
            Picker("Minuten", selection: minuteBinding) {
                ForEach(minuteOptions, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            Text("min")
                .foregroundStyle(.secondary)
            Picker("Sekunden", selection: secondBinding) {
                ForEach(secondOptions, id: \.self) { value in
                    Text(value < 10 ? "0\(value)" : "\(value)").tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            Text("s")
                .foregroundStyle(.secondary)
        }
    }
}

/// Großer, gut treffbarer Button für die Laufansicht.
struct BigButtonStyle: ButtonStyle {
    var color: Color
    var minHeight: CGFloat = 68

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
