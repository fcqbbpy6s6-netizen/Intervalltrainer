import Foundation
import IntervalCore
import SwiftUI

/// Speichert die Pläne als JSON-Datei im App-Verzeichnis.
final class PlanStore: ObservableObject {
    @Published private(set) var plans: [Plan] = []

    private let fileURL: URL

    init() {
        let fileManager = FileManager.default
        let directory = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory
        fileURL = directory.appendingPathComponent("plans.json")

        if let data = try? Data(contentsOf: fileURL) {
            if let decoded = try? JSONDecoder().decode([Plan].self, from: data) {
                plans = decoded
            } else {
                // Unlesbare Datei nicht überschreiben, sondern beiseitelegen.
                let backup = directory.appendingPathComponent("plans-defekt.json")
                try? fileManager.removeItem(at: backup)
                try? fileManager.moveItem(at: fileURL, to: backup)
                plans = PlanTemplates.all()
                save()
            }
        } else {
            // Erster Start: Beispielvorlagen anlegen.
            plans = PlanTemplates.all()
            save()
        }
    }

    func plan(id: UUID) -> Plan? {
        plans.first { $0.id == id }
    }

    /// Speichert einen neuen oder geänderten Plan.
    func upsert(_ plan: Plan) {
        var stored = plan
        if stored.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            stored.name = "Neuer Plan"
        }
        if let index = plans.firstIndex(where: { $0.id == stored.id }) {
            plans[index] = stored
        } else {
            plans.insert(stored, at: 0)
        }
        save()
    }

    func duplicate(_ plan: Plan) {
        let copy = plan.duplicated()
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans.insert(copy, at: index + 1)
        } else {
            plans.append(copy)
        }
        save()
    }

    func delete(id: UUID) {
        plans.removeAll { $0.id == id }
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        plans.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func addTemplates() {
        plans.append(contentsOf: PlanTemplates.all())
        save()
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(plans) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
