// Seeded, realistic histories for screenshots (OOB_SCENARIO=<id>), ported 1:1 from web/src/app/scenarios.ts.
// Same RNG (mulberry32) and the same seeds, so logs land on the same minutes as the prototype.
import Foundation

struct Mulberry32 {
    var seed: UInt32
    init(_ s: Int) { seed = UInt32(truncatingIfNeeded: s) }
    mutating func next() -> Double {
        seed = seed &+ 0x6D2B79F5
        var t = (seed ^ (seed >> 15)) &* (1 | seed)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        return Double(t ^ (t >> 14)) / 4294967296
    }
}

// Hour weights: busy after lunch and late evening, like the spec's example pattern.
private let W: [Double] = [0.3, 0.1, 0, 0, 0, 0, 0, 0.4, 1, 0.8, 0.8, 0.9, 1.8, 1.9, 1, 0.9, 1, 0.9, 1, 0.9, 1.1, 1.7, 1.9, 1.2]

private func dayLogs(_ day: Double, _ n: Int, _ r: inout Mulberry32, _ untilHour: Double = 24) -> [LogEntry] {
    let w = W.enumerated().map { Double($0.offset) < untilHour ? $0.element : 0 }
    let sum = w.reduce(0, +)
    var out: [LogEntry] = []
    for i in 0..<max(0, n) {
        var x = r.next() * sum, h = 0
        while h < 23 && x > w[h] { x -= w[h]; h += 1 }
        let maxMin = Double(h) == floor(untilHour) ? max(1, (untilHour - Double(h)) * 60 - 2) : 59
        let at = day + Double(h) * 36e5 + floor(r.next() * maxMin) * 6e4
        out.append(LogEntry(id: "l\(Int(day))-\(i)", at: at, source: r.next() < 0.7 ? .widget : .app))
    }
    return out.sorted { $0.at < $1.at }
}

private struct Spec {
    var daysAgo: Int
    var hour: Double
    var used: [Int]
    var today: Int
    var beaten = 0
    var gaveIn = 0
    var setup = Setup()
    var allowed: Bool?
    var reviewed: [Int] = []
    var quitSeen = false
    var morning: Bool?
    var weeks: Double?
}

private func build(_ a: Answers, _ sp: Spec) -> (AppState, Double) {
    let today = midnight(Date().timeIntervalSince1970 * 1000)
    let clock = today + sp.hour * 36e5
    var r = Mulberry32(7 + sp.daysAgo * 31 + sp.today)
    var answers = a
    if let w = sp.weeks { answers.weeks = w }
    var s = freshState(answers, addDays(today, -sp.daysAgo))
    s.welcomed = true
    s.signature = nil
    var logs: [LogEntry] = []
    for (d, n) in sp.used.enumerated() { logs += dayLogs(addDays(s.start, d), n, &r) }
    logs += dayLogs(today, sp.today, &r, sp.hour)
    s.logs = logs.filter { $0.at <= clock }

    var cr: [Craving] = []
    let span = max(1, (clock - s.start) / 36e5)
    var kinds: [Craving.Outcome] = Array(repeating: .beaten, count: sp.beaten) + Array(repeating: .gaveIn, count: sp.gaveIn)
    if kinds.count > 1 {
        for i in stride(from: kinds.count - 1, to: 0, by: -1) {
            let j = Int(floor(r.next() * Double(i + 1)))
            kinds.swapAt(i, j)
        }
    }
    for (i, outcome) in kinds.enumerated() {
        let at = s.start + floor(((Double(i) + 0.3 + r.next() * 0.4) / Double(kinds.count)) * span) * 36e5 + floor(r.next() * 50) * 6e4
        cr.append(Craving(id: "c\(i)", at: min(at, clock - 6e5), outcome: outcome, method: r.next() < 0.75 ? .breathe : .reasons))
    }
    s.cravings = cr

    var ci: [CheckIn] = []
    let moods: [Mood] = [.good, .ok, .hard]
    for d in 0..<sp.used.count {
        let k = dayKey(addDays(s.start, d) + 12 * 36e5)
        ci.append(CheckIn(date: k, kind: .morning))
        let w = d / 7
        let bud = s.budgets.indices.contains(w) ? s.budgets[w] : 0
        ci.append(CheckIn(date: k, kind: .evening, mood: sp.used[d] <= bud ? moods[d % 2] : .hard))
    }
    if sp.morning ?? (sp.hour >= 11) { ci.append(CheckIn(date: dayKey(clock), kind: .morning)) }
    s.checkins = ci

    s.setup = sp.setup
    s.notifsAllowed = sp.allowed ?? sp.setup.checkins
    s.reviewed = sp.reviewed
    s.quitSeen = sp.quitSeen
    // celebrations already earned before "now" were seen on earlier days
    s.celebrated = earned(s, derive(s, clock)).map(\.key)
    return (s, clock)
}

// a gently realistic taper: usually a little under budget, sometimes over
private func taper(_ a: Answers, _ days: Int, _ seed: Int) -> [Int] {
    let s = freshState(a)
    var r = Mulberry32(seed)
    return (0..<days).map { d in
        let w = d / 7
        let bud = s.budgets.indices.contains(w) ? s.budgets[w] : 0
        if bud == 0 { return d % 7 < 2 ? 2 - (d % 7) : 0 }
        return max(0, Int(jsRound(Double(bud) * (0.82 + r.next() * 0.26))))
    }
}

func scenario(_ id: String, _ a: Answers) -> (AppState, Double)? {
    let b = freshState(a).budgets
    let b0 = b[0], b1 = b.count > 1 ? b[1] : b[0]
    func rnd(_ x: Double) -> Int { Int(jsRound(x)) }
    let all = Setup(widget: true, checkins: true, sos: true, reasons: true)
    switch id {
    case "day1": return build(a, Spec(daysAgo: 0, hour: 9.2, used: [], today: 0, morning: false))
    case "midweek": return build(a, Spec(daysAgo: 3, hour: 15.33, used: [b0 - 1, b0 + 2, b0 - 3], today: rnd(Double(b0) * 0.6), beaten: 4, gaveIn: 1, setup: Setup(widget: true, sos: true)))
    case "near": return build(a, Spec(daysAgo: 3, hour: 18.67, used: [b0 - 1, b0 + 2, b0 - 3], today: rnd(Double(b0) * 0.86), beaten: 5, gaveIn: 1, setup: Setup(widget: true, checkins: true, sos: true)))
    case "over": return build(a, Spec(daysAgo: 4, hour: 21.25, used: [b0 - 1, b0 + 2, b0 - 3, b0], today: b0 + 4, beaten: 5, gaveIn: 2, setup: Setup(widget: true, checkins: true, sos: true)))
    case "stepdown": return build(a, Spec(daysAgo: 7, hour: 8.5, used: [b0 - 1, b0 + 1, b0 - 2, b0 + 2, b0 - 3, b0 - 4, b0 - 5], today: 0, beaten: 9, gaveIn: 2, setup: all, morning: false))
    case "adaptive": return build(a, Spec(daysAgo: 11, hour: 13, used: [b0 - 1, b0, b0 - 2, b0 + 1, b0 - 3, b0 - 1, b0 - 4, b1 + 4, b1 + 2, b1 - 1, b1 + 3], today: rnd(Double(b1) * 0.5), beaten: 11, gaveIn: 3, setup: all, reviewed: [1]))
    case "free":
        let n = b.count * 7
        return build(a, Spec(daysAgo: n + 4, hour: 14, used: taper(a, n, 3) + [0, 0, 0, 0], today: 0, beaten: 31, gaveIn: 6, setup: all, reviewed: Array(b.indices), quitSeen: true))
    case "quitday":
        let n = b.count * 7
        return build(a, Spec(daysAgo: n, hour: 10.5, used: taper(a, n, 5), today: 0, beaten: 28, gaveIn: 6, setup: all, reviewed: Array(b.indices), quitSeen: false))
    case "rough": return build(a, Spec(daysAgo: 7, hour: 8.5, used: [b0 + 3, b0 + 1, b0 - 1, b0 + 4, b0 + 2, b0 + 2, b0 - 2], today: 0, beaten: 3, gaveIn: 5, setup: Setup(widget: true, checkins: true, sos: true), morning: false))
    default: return nil
    }
}
