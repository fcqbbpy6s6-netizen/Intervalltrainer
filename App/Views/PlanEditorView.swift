import IntervalCore
import SwiftUI

/// Standardwerte für neu angelegte Phasen.
enum PhaseDefaults {
    static func phase(_ kind: PhaseKind) -> Phase {
        switch kind {
        case .warmup: return Phase(kind: .warmup, goal: .time(seconds: 600))
        case .work: return Phase(kind: .work, goal: .distance(meters: 400))
        case .recovery: return Phase(kind: .recovery, goal: .time(seconds: 90))
        case .cooldown: return Phase(kind: .cooldown, goal: .time(seconds: 600))
        }
    }

    static func block() -> RepeatBlock {
        RepeatBlock(repeatCount: 6, phases: [
            Phase(kind: .work, goal: .distance(meters: 400)),
            Phase(kind: .recovery, goal: .distance(meters: 200))
        ])
    }
}

/// Editor für einen Plan. Arbeitet auf einer Kopie und speichert erst bei „Sichern“.
struct PlanEditorView: View {
    @State private var draft: Plan
    private let isNew: Bool
    private let onSave: (Plan) -> Void

    @Environment(\.dismiss) private var dismiss

    init(plan: Plan, onSave: @escaping (Plan) -> Void) {
        _draft = State(initialValue: plan)
        self.isNew = plan.items.isEmpty && plan.name.isEmpty
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Name") {
                    TextField("Name des Plans", text: $draft.name)
                }

                Section {
                    if draft.items.isEmpty {
                        Text("Füge unten Phasen oder einen Wiederholungsblock hinzu.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach($draft.items) { $item in
                        NavigationLink {
                            PlanItemEditorView(item: $item)
                        } label: {
                            PlanItemRowView(item: item)
                        }
                    }
                    .onDelete { offsets in
                        draft.items.remove(atOffsets: offsets)
                    }
                    .onMove { source, destination in
                        draft.items.move(fromOffsets: source, toOffset: destination)
                    }
                } header: {
                    Text("Ablauf")
                } footer: {
                    Text(draft.summary.text)
                }

                Section("Hinzufügen") {
                    ForEach(PhaseKind.allCases, id: \.self) { kind in
                        Button {
                            add(.phase(PhaseDefaults.phase(kind)), kind: kind)
                        } label: {
                            Label(kind.displayName, systemImage: kind.symbolName)
                        }
                    }
                    Button {
                        add(.block(PhaseDefaults.block()), kind: nil)
                    } label: {
                        Label("Wiederholungsblock", systemImage: "repeat")
                    }
                }
            }
            .navigationTitle(isNew ? "Neuer Plan" : "Plan bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        onSave(draft)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    EditButton()
                }
            }
        }
        .interactiveDismissDisabled()
    }

    /// Fügt einen Eintrag an sinnvoller Stelle ein: Einlaufen vorn,
    /// alles andere vor einem abschließenden Auslaufen.
    private func add(_ item: PlanItem, kind: PhaseKind?) {
        if kind == .warmup {
            draft.items.insert(item, at: 0)
            return
        }
        if kind != .cooldown, let last = draft.items.last, case .phase(let phase) = last, phase.kind == .cooldown {
            draft.items.insert(item, at: draft.items.count - 1)
            return
        }
        draft.items.append(item)
    }
}

/// Öffnet je nach Eintrag den Phasen- oder den Block-Editor.
struct PlanItemEditorView: View {
    @Binding var item: PlanItem

    var body: some View {
        switch item {
        case .phase(let phase):
            PhaseEditorView(phase: Binding(
                get: {
                    if case .phase(let current) = item { return current }
                    return phase
                },
                set: { item = .phase($0) }
            ))
        case .block(let block):
            BlockEditorView(block: Binding(
                get: {
                    if case .block(let current) = item { return current }
                    return block
                },
                set: { item = .block($0) }
            ))
        }
    }
}

/// Editor für einen Wiederholungsblock.
struct BlockEditorView: View {
    @Binding var block: RepeatBlock

    var body: some View {
        List {
            Section("Wiederholungen") {
                Stepper(value: $block.repeatCount, in: 1...50) {
                    Text("\(block.repeatCount)× wiederholen")
                }
            }

            Section("Phasen im Block") {
                if block.phases.isEmpty {
                    Text("Füge unten Phasen hinzu.")
                        .foregroundStyle(.secondary)
                }
                ForEach($block.phases) { $phase in
                    NavigationLink {
                        PhaseEditorView(phase: $phase)
                    } label: {
                        PhaseRowView(phase: phase)
                    }
                }
                .onDelete { offsets in
                    block.phases.remove(atOffsets: offsets)
                }
                .onMove { source, destination in
                    block.phases.move(fromOffsets: source, toOffset: destination)
                }
            }

            Section("Hinzufügen") {
                ForEach(PhaseKind.allCases, id: \.self) { kind in
                    Button {
                        block.phases.append(PhaseDefaults.phase(kind))
                    } label: {
                        Label(kind.displayName, systemImage: kind.symbolName)
                    }
                }
            }
        }
        .navigationTitle("Wiederholungsblock")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
    }
}
