// All the nicotine math lives here, ported 1:1 from web/src/calc.ts.
// Every number is an estimate and the UI says so.

import Foundation

enum Device: String, Codable, CaseIterable {
    case disposable, pod, refill, pouch, combo
}

struct Answers: Codable, Equatable {
    var device: Device?
    var duration: String?
    var strength: Double? // mg/mL of e-liquid (5% ≈ 50)
    var dispSize: Double? // claimed puffs per disposable
    var dispDays: Double? // days one disposable lasts
    var podsPerDay: Double?
    var hitsPerDay: Double? // times they pick it up a day
    var mlPerDay: Double?
    var pouchesPerDay: Double?
    var pouchMg: Double?
    var firstHit: String? // 'lt5' | '5to30' | '31to60' | 'gt60'
    var triggers: [String]?
    var weeklySpend: Double?
    var tried: String? // 'never' | 'once' | 'few' | 'lost'
    var hardParts: [String]?
    var reasons: [String]?
    var name: String?
    var age: String?
    var weeks: Double?
    var signed: Bool?
}

/// JavaScript's Math.round (half rounds toward +infinity).
@inline(__always) func jsRound(_ x: Double) -> Double { (x + 0.5).rounded(.down) }

enum Calc {
    static func usesVape(_ a: Answers) -> Bool { a.device != .pouch }
    static func usesPouch(_ a: Answers) -> Bool { a.device == .pouch || a.device == .combo }

    // Reference point: Juul says one 0.7 mL, 5% pod (~41 mg) ≈ a pack of 20.
    // So ~2 mg of nicotine in e-liquid ≈ 1 cigarette.
    static let LIQUID_MG_PER_CIG = 2.05
    // A ~6 mg pouch delivers roughly what one cigarette does.
    static let POUCH_MG_PER_CIG = 6.0
    // Typical e-liquid inside a disposable, by the puff count on the box.
    static let DISP_ML: [Double: Double] = [800: 2, 3000: 8, 6000: 13, 12000: 18]

    static func liquidMlPerDay(_ a: Answers) -> Double {
        if !usesVape(a) { return 0 }
        switch a.device {
        case .disposable, .combo:
            return (DISP_ML[a.dispSize ?? 6000] ?? 13) / (a.dispDays ?? 5)
        case .pod:
            return (a.podsPerDay ?? 1) * 0.8
        case .refill:
            return a.mlPerDay ?? 3
        default:
            return 0
        }
    }

    static func nicotineMgPerDay(_ a: Answers) -> Int {
        let vapeMg = liquidMlPerDay(a) * (a.strength ?? 50)
        let pouchMg = usesPouch(a) ? (a.pouchesPerDay ?? 0) * (a.pouchMg ?? 6) : 0
        return Int(jsRound(vapeMg + pouchMg))
    }

    static func cigsPerDay(_ a: Answers) -> Double {
        let fromVape = (liquidMlPerDay(a) * (a.strength ?? 50)) / LIQUID_MG_PER_CIG
        let fromPouch = usesPouch(a) ? ((a.pouchesPerDay ?? 0) * (a.pouchMg ?? 6)) / POUCH_MG_PER_CIG : 0
        return fromVape + fromPouch
    }

    static func packsPerDay(_ a: Answers) -> Double { jsRound((cigsPerDay(a) / 20) * 10) / 10 }

    static func yearlySpend(_ a: Answers) -> Int { Int(jsRound((a.weeklySpend ?? 30) * 52)) }

    // Dependence: time to first use after waking is the single strongest
    // question in the Fagerström test; amount per day is the second.
    struct Dependence { let score: Int; let label: String; let level: Int }
    static func dependence(_ a: Answers) -> Dependence {
        let t = ["lt5": 3, "5to30": 2, "31to60": 1, "gt60": 0][a.firstHit ?? "5to30"] ?? 2
        let c = cigsPerDay(a)
        let amt = c > 30 ? 3 : c > 20 ? 2 : c > 10 ? 1 : 0
        let score = t + amt // 0..6
        let level = score >= 5 ? 3 : score >= 3 ? 2 : score >= 2 ? 1 : 0
        let label = ["Low", "Moderate", "High", "Very high"][level]
        return Dependence(score: score, label: label, level: level)
    }

    static func recommendedWeeks(_ a: Answers) -> Int { [2, 4, 6, 6][dependence(a).level] }

    // Daily budget per week, stepping down to zero in the last week.
    // The unit is what they actually count: puffs, or pouches if pouch-only.
    static func budgetUnit(_ a: Answers) -> String { a.device == .pouch ? "pouches" : "hits" }

    static func startAmount(_ a: Answers) -> Int {
        Int(budgetUnit(a) == "pouches" ? (a.pouchesPerDay ?? 8) : (a.hitsPerDay ?? 30))
    }

    static func weeks(_ a: Answers) -> Int { a.weeks.map { Int($0) } ?? recommendedWeeks(a) }

    static func plan(_ a: Answers) -> [Int] {
        let weeks = weeks(a)
        let start = Double(startAmount(a))
        var steps: [Int] = []
        for w in 0..<weeks {
            let frac = 1 - Double(w + 1) / Double(weeks)
            let v = w == weeks - 1 ? 0 : start * max(0.1, 0.85 * frac + 0.05)
            steps.append(Int(jsRound(v)))
        }
        return steps
    }

    static func quitDate(_ a: Answers, from: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: 7 * weeks(a), to: from) ?? from
    }

    static func fmtDate(_ d: Date, withYear: Bool = false) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = withYear ? "MMM d, yyyy" : "MMM d"
        return f.string(from: d)
    }

    static func money(_ n: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 3
        return "$" + (f.string(from: NSNumber(value: n)) ?? String(n))
    }
    static func money(_ n: Int) -> String { money(Double(n)) }

    static func savedByQuit(_ a: Answers) -> Int {
        // first-year saving: a full year of spend minus roughly half spend during the taper
        Int(jsRound(Double(yearlySpend(a)) - (a.weeklySpend ?? 30) * Double(weeks(a)) * 0.5))
    }
}
