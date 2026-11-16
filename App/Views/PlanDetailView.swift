import IntervalCore
import SwiftUI

/// Vorschau eines Plans mit Gesamtwerten und Start des Laufs.
struct PlanDetailView: View {
    let planID: UUID

    @EnvironmentObject private var store: PlanStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var services: AppServices
    @Environment(\.dismiss) private var dismiss

    @State private var editorPlan: Plan?
    @State private var runPlan: Plan?
    @State private var confirmDelete = false

    var body: some View {
        if let plan = store.plan(id: planID) {
            content(plan)
        } else {
            ContentUnavailableView("Plan nicht gefunden", systemImage: "questionmark.circle")
        }
    }

    private func content(_ plan: Plan) -> some View {
        let summary = plan.summary
        return List {
            Section("Übersicht") {
                LabeledContent("Gesamt", value: summary.text)
                LabeledContent("Schritte", value: "\(summary.stepCount)")
                if let seconds = summary.exactSeconds, summary.stepCount > 0 {
                    LabeledContent("Gesamtdauer", value: RunFormat.clock(seconds))
                }
                if let meters = summary.exactMeters, summary.stepCount > 0 {
                    LabeledContent("Gesamtstrecke", value: RunFormat.distance(meters: meters))
                }
            }
            Section("Ablauf") {
                if plan.items.isEmpty {
                    Text("Dieser Plan hat noch keine Phasen.")
                        .foregroundStyle(.secondary)
                }
                ForEach(plan.items) { item in
                    PlanItemRowView(item: item)
                }
            }
        }
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        editorPlan = plan
                    } label: {
                        Label("Bearbeiten", systemImage: "pencil")
                    }
                    Button {
                        store.duplicate(plan)
                        dismiss()
                    } label: {
                        Label("Duplizieren", systemImage: "plus.square.on.square")
                    }
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Aktionen")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                runPlan = plan
            } label: {
                Label("Lauf starten", systemImage: "figure.run")
            }
            .buttonStyle(BigButtonStyle(color: .green, minHeight: 60))
            .disabled(summary.stepCount == 0)
            .opacity(summary.stepCount == 0 ? 0.4 : 1)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .sheet(item: $editorPlan) { draft in
            PlanEditorView(plan: draft) { saved in
                store.upsert(saved)
            }
        }
        .fullScreenCover(item: $runPlan) { selected in
            RunView(plan: selected, speech: services.speech, location: services.location, settings: settings)
                .environmentObject(settings)
        }
        .confirmationDialog("Plan wirklich löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                store.delete(id: plan.id)
                dismiss()
            }
            Button("Abbrechen", role: .cancel) {}
        }
    }
}
