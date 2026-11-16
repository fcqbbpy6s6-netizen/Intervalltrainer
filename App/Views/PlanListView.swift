import IntervalCore
import SwiftUI

/// Startansicht: Liste aller gespeicherten Pläne.
struct PlanListView: View {
    @EnvironmentObject private var store: PlanStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var services: AppServices

    @State private var editorPlan: Plan?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.plans) { plan in
                    NavigationLink(value: plan.id) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plan.name)
                                .font(.headline)
                            Text(plan.summary.text)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            store.delete(id: plan.id)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            store.duplicate(plan)
                        } label: {
                            Label("Duplizieren", systemImage: "plus.square.on.square")
                        }
                        .tint(.blue)
                    }
                    .contextMenu {
                        Button {
                            editorPlan = plan
                        } label: {
                            Label("Bearbeiten", systemImage: "pencil")
                        }
                        Button {
                            store.duplicate(plan)
                        } label: {
                            Label("Duplizieren", systemImage: "plus.square.on.square")
                        }
                        Button(role: .destructive) {
                            store.delete(id: plan.id)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
                .onMove { source, destination in
                    store.move(from: source, to: destination)
                }
            }
            .overlay {
                if store.plans.isEmpty {
                    ContentUnavailableView(
                        "Keine Pläne",
                        systemImage: "figure.run",
                        description: Text("Lege über das Plus einen neuen Plan an oder füge die Beispielvorlagen hinzu.")
                    )
                }
            }
            .navigationTitle("Intervallpläne")
            .navigationDestination(for: UUID.self) { planID in
                PlanDetailView(planID: planID)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Einstellungen")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            editorPlan = Plan(name: "")
                        } label: {
                            Label("Neuer Plan", systemImage: "square.and.pencil")
                        }
                        Button {
                            store.addTemplates()
                        } label: {
                            Label("Beispielvorlagen hinzufügen", systemImage: "tray.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Hinzufügen")
                }
            }
            .sheet(item: $editorPlan) { plan in
                PlanEditorView(plan: plan) { saved in
                    store.upsert(saved)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(settings)
                    .environmentObject(services)
            }
        }
    }
}
