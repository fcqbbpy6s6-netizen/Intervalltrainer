import Foundation

/// Wandelt Zahlen, Zeiten, Strecken und Pace in natürlich gesprochenes Deutsch um.
public enum GermanSpeech {
    private static let small = [
        "null", "eins", "zwei", "drei", "vier", "fünf", "sechs", "sieben", "acht", "neun",
        "zehn", "elf", "zwölf", "dreizehn", "vierzehn", "fünfzehn", "sechzehn", "siebzehn",
        "achtzehn", "neunzehn"
    ]

    private static let tens = [
        "", "", "zwanzig", "dreißig", "vierzig", "fünfzig", "sechzig", "siebzig", "achtzig", "neunzig"
    ]

    private static func below100(_ n: Int) -> String {
        if n < 20 {
            return small[n]
        }
        let ten = n / 10
        let one = n % 10
        if one == 0 {
            return tens[ten]
        }
        let prefix = one == 1 ? "ein" : small[one]
        return prefix + "und" + tens[ten]
    }

    private static func below1000(_ n: Int) -> String {
        let hundred = n / 100
        let rest = n % 100
        var text = ""
        if hundred > 0 {
            text = (hundred == 1 ? "ein" : small[hundred]) + "hundert"
        }
        if rest > 0 || hundred == 0 {
            text += below100(rest)
        }
        return text
    }

    /// Zahlwort für 0 bis 999 999, z. B. 21 → „einundzwanzig“.
    public static func spell(_ number: Int) -> String {
        guard number >= 0, number < 1_000_000 else { return "\(number)" }
        if number < 1000 {
            return below1000(number)
        }
        let thousands = number / 1000
        let rest = number % 1000
        var prefix = below1000(thousands)
        if prefix.hasSuffix("eins") {
            prefix.removeLast()
        }
        var text = prefix + "tausend"
        if rest > 0 {
            text += below1000(rest)
        }
        return text
    }

    /// Zahl mit Substantiv, z. B. „eine Minute“, „zwei Minuten“, „ein Meter“.
    public static func count(_ number: Int, singular: String, plural: String, feminine: Bool) -> String {
        if number == 1 {
            return (feminine ? "eine " : "ein ") + singular
        }
        return spell(number) + " " + plural
    }

    /// Dauer, z. B. 270 → „vier Minuten dreißig“, 30 → „dreißig Sekunden“.
    public static func duration(seconds: Int) -> String {
        let s = max(0, seconds)
        let hours = s / 3600
        let minutes = (s % 3600) / 60
        let secs = s % 60
        if hours > 0 {
            var text = count(hours, singular: "Stunde", plural: "Stunden", feminine: true)
            if minutes > 0 {
                text += " " + count(minutes, singular: "Minute", plural: "Minuten", feminine: true)
            }
            return text
        }
        if minutes == 0 {
            return count(secs, singular: "Sekunde", plural: "Sekunden", feminine: true)
        }
        var text = count(minutes, singular: "Minute", plural: "Minuten", feminine: true)
        if secs > 0 {
            text += " " + spell(secs)
        }
        return text
    }

    /// Pace, z. B. 270 → „vier Minuten dreißig“.
    public static func pace(secPerKm: Int) -> String {
        duration(seconds: secPerKm)
    }

    /// Pace-Bereich, z. B. „vier Minuten dreißig bis vier Minuten vierzig“.
    public static func paceRange(_ range: PaceRange) -> String {
        if range.fastSecPerKm == range.slowSecPerKm {
            return pace(secPerKm: range.fastSecPerKm)
        }
        return pace(secPerKm: range.fastSecPerKm) + " bis " + pace(secPerKm: range.slowSecPerKm)
    }

    /// Strecke eines Plans, z. B. „vierhundert Meter“, „ein Kilometer“, „eins Komma fünf Kilometer“.
    public static func distance(meters: Int) -> String {
        let m = max(0, meters)
        if m < 1000 || m % 100 != 0 {
            return count(m, singular: "Meter", plural: "Meter", feminine: false)
        }
        return kilometers(meters: Double(m))
    }

    /// Gemessene Strecke in Kilometern mit bis zu zwei Nachkommastellen,
    /// z. B. 5230 → „fünf Komma zwei drei Kilometer“.
    public static func kilometers(meters: Double) -> String {
        let hundredths = Int((max(0, meters) / 10).rounded())
        let whole = hundredths / 100
        let frac = hundredths % 100
        if frac == 0 {
            return count(whole, singular: "Kilometer", plural: "Kilometer", feminine: false)
        }
        var text = spell(whole) + " Komma " + spell(frac / 10)
        if frac % 10 != 0 {
            text += " " + spell(frac % 10)
        }
        return text + " Kilometer"
    }
}
