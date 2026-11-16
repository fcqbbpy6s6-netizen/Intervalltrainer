import Foundation

/// Berechnet die aktuelle Pace über ein gleitendes Zeitfenster.
public struct PaceWindow: Sendable {
    private struct Entry: Sendable {
        var time: TimeInterval
        var distance: Double
    }

    /// Länge des Fensters in Sekunden.
    public var window: TimeInterval
    /// Mindestspanne, bevor eine Pace gemeldet wird.
    public var minSpan: TimeInterval = 5
    /// Mindeststrecke im Fenster, sonst gilt der Läufer als stehend.
    public var minDistance: Double = 5
    /// Ohne neuen Messpunkt innerhalb dieser Zeit gibt es keine Pace.
    public var staleAfter: TimeInterval = 8
    /// Langsamere Werte (Sekunden pro Kilometer) werden nicht gemeldet.
    public var maxPace: Double = 1500

    private var entries: [Entry] = []

    public init(window: TimeInterval = 15) {
        self.window = window
    }

    public mutating func reset() {
        entries.removeAll()
    }

    /// Fügt einen Messpunkt hinzu: Zeit in Sekunden und bisherige Gesamtstrecke in Metern.
    public mutating func add(time: TimeInterval, distance: Double) {
        if let last = entries.last, time <= last.time {
            return
        }
        entries.append(Entry(time: time, distance: distance))
        // Ältesten Eintrag behalten, solange der zweitälteste das Fenster noch nicht abdeckt.
        while entries.count > 2, time - entries[1].time >= window {
            entries.removeFirst()
        }
    }

    /// Aktuelle Pace in Sekunden pro Kilometer, oder nil, wenn sie nicht bestimmbar ist.
    public func pace(now: TimeInterval) -> Double? {
        guard entries.count >= 2, let first = entries.first, let last = entries.last else { return nil }
        guard now - last.time <= staleAfter else { return nil }
        let span = last.time - first.time
        let distance = last.distance - first.distance
        guard span >= minSpan, distance >= minDistance else { return nil }
        let pace = span / distance * 1000
        return pace <= maxPace ? pace : nil
    }
}
