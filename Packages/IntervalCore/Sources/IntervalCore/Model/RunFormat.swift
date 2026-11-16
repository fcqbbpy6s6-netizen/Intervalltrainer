import Foundation

/// Textformate für die Anzeige (nicht für die Sprachausgabe).
public enum RunFormat {
    private static func pad(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    /// „4:30“ oder „1:05:00“.
    public static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return "\(h):\(pad(m)):\(pad(sec))"
        }
        return "\(m):\(pad(sec))"
    }

    /// „400 m“, „1 km“, „1,5 km“, „1,25 km“.
    public static func distance(meters: Int) -> String {
        let m = max(0, meters)
        if m < 1000 {
            return "\(m) m"
        }
        let hundredths = Int((Double(m) / 10).rounded())
        let whole = hundredths / 100
        let frac = hundredths % 100
        if frac == 0 {
            return "\(whole) km"
        }
        if frac % 10 == 0 {
            return "\(whole),\(frac / 10) km"
        }
        return "\(whole),\(pad(frac)) km"
    }

    /// Kilometer mit festen zwei Nachkommastellen, z. B. „5,23“.
    public static func kilometers(_ meters: Double) -> String {
        let hundredths = Int((max(0, meters) / 10).rounded())
        return "\(hundredths / 100),\(pad(hundredths % 100))"
    }

    /// Pace als „4:30“.
    public static func pace(_ secPerKm: Int) -> String {
        clock(secPerKm)
    }

    /// Pace-Bereich als „4:30–4:40 /km“.
    public static func paceRange(_ range: PaceRange) -> String {
        if range.fastSecPerKm == range.slowSecPerKm {
            return "\(pace(range.fastSecPerKm)) /km"
        }
        return "\(pace(range.fastSecPerKm))–\(pace(range.slowSecPerKm)) /km"
    }

    /// Ziel einer Phase als „1:30“ oder „400 m“.
    public static func goal(_ goal: PhaseGoal) -> String {
        switch goal {
        case .time(let seconds): return clock(seconds)
        case .distance(let meters): return distance(meters: meters)
        }
    }
}
