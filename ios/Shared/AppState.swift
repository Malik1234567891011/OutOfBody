// App state after the paywall, ported 1:1 from web/src/app/store.ts.
// Everything lives on the device (App Group container) so the widgets read and write the same data.
// Every number on screen is derived from this state by derive(); nothing is hard-coded.
// Times are JS-style milliseconds since 1970 so the formulas read the same as the prototype.

import Foundation

enum Source: String, Codable { case app, widget, control, sos }
struct LogEntry: Codable, Equatable, Identifiable { var id: String; var at: Double; var source: Source }
struct Craving: Codable, Equatable {
    enum Outcome: String, Codable { case beaten, gaveIn }
    enum Method: String, Codable { case breathe, reasons }
    var id: String; var at: Double; var outcome: Outcome; var method: Method
}
enum Mood: String, Codable { case good, ok, hard }
struct CheckIn: Codable, Equatable {
    enum Kind: String, Codable { case morning, evening }
    var date: String; var kind: Kind; var mood: Mood?; var note: String?
}
struct Slip: Codable, Equatable { var at: Double }
struct Notif: Codable, Equatable, Identifiable {
    var id: String; var label: String; var detail: String; var time: String?; var when: String?; var on: Bool
}
struct Setup: Codable, Equatable {
    var widget = false, checkins = false, sos = false, reasons = false
    var all: Bool { widget && checkins && sos && reasons }
}
/// Analytics events raised outside the app (widget, control, intents); the app forwards them on next open.
struct PendingEvent: Codable, Equatable { var name: String; var props: [String: String]; var at: Double }

struct AppState: Codable, Equatable {
    var v = 1
    var answers: Answers
    var start: Double // local midnight of day 1
    var budgets: [Int] // daily budget per week (adaptive weeks are inserted here)
    var extraWeeks: Int
    var logs: [LogEntry]
    var cravings: [Craving]
    var checkins: [CheckIn]
    var slips: [Slip]
    var reasons: [String]
    var setup: Setup
    var notifsAllowed: Bool
    var notifs: [Notif]
    var reviewed: [Int] // weeks whose step-down review was handled
    var adaptiveDone: [Int] // weeks where the adaptive card was answered
    var quitSeen: Bool
    var welcomed: Bool
    var celebrated: [String]
    var signature: String? // file name of the pledge signature PNG in the App Group container
    var pending: [PendingEvent] = []
    var installAt: Double = 0
}

let DAY: Double = 864e5
let HOUR: Double = 36e5

// MARK: - clock (scenarios pin "now" to a time of day; it still ticks)

enum Clock {
    static var offset: Double = 0
    static func now() -> Double { Date().timeIntervalSince1970 * 1000 + offset }
    static func set(_ ms: Double) { offset = ms - Date().timeIntervalSince1970 * 1000 }
}
func now() -> Double { Clock.now() }
func toDate(_ t: Double) -> Date { Date(timeIntervalSince1970: t / 1000) }
func ms(_ d: Date) -> Double { d.timeIntervalSince1970 * 1000 }

func midnight(_ t: Double) -> Double { ms(Calendar.current.startOfDay(for: toDate(t))) }
func addDays(_ t: Double, _ n: Int) -> Double { ms(Calendar.current.date(byAdding: .day, value: n, to: toDate(t)) ?? toDate(t)) }
func dayKey(_ t: Double) -> String {
    let c = Calendar.current.dateComponents([.year, .month, .day], from: toDate(t))
    return "\(c.year!)-\(c.month!)-\(c.day!)"
}
func hourOf(_ t: Double) -> Int { Calendar.current.component(.hour, from: toDate(t)) }
func dayIndex(_ s: AppState, _ t: Double) -> Int { Int(jsRound((midnight(t) - s.start) / DAY)) }
func uid() -> String { String(UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(8)) }

// MARK: - notifications (defaults from onboarding answers)

struct TriggerNotif { let label: String; let time: String; var when: String?; let detail: String }
let TRIGGER_NOTIFS: [String: [TriggerNotif]] = [
    "wake": [TriggerNotif(label: "Waking up", time: "07:30", detail: "Breakfast first, first hit after.")],
    "meals": [TriggerNotif(label: "After lunch", time: "12:30", detail: "Walk for 3 minutes before you decide."),
              TriggerNotif(label: "After dinner", time: "18:30", detail: "Walk for 3 minutes before you decide.")],
    "stress": [TriggerNotif(label: "Afternoon stress", time: "15:00", detail: "Stressful moment? Hit SOS.")],
    "bored": [TriggerNotif(label: "Bored moment", time: "15:00", detail: "10 slow breaths before you reach for it.")],
    "drive": [TriggerNotif(label: "Commute", time: "17:30", detail: "Leave it in the bag until you park.")],
    "work": [TriggerNotif(label: "Work break", time: "10:30", detail: "A look at today's budget.")],
    "drink": [TriggerNotif(label: "Going out", time: "21:00", when: "Fri", detail: "Decide your budget before the first drink.")],
    "social": [TriggerNotif(label: "Friends who vape", time: "20:00", when: "Sat", detail: "Hold off 5 minutes. No need to explain.")],
    "bed": [TriggerNotif(label: "Before bed", time: "22:00", detail: "The last one of the night counts too.")],
]

func defaultNotifs(_ a: Answers, _ budget: Int, _ unit: String) -> [Notif] {
    var out = [Notif(id: "morning", label: "Morning budget", detail: "\"Today's budget: \(budget) \(unit).\"", time: "08:00", on: true)]
    var seen = Set<String>()
    for t in a.triggers ?? [] {
        for n in TRIGGER_NOTIFS[t] ?? [] {
            let k = n.time + (n.when ?? "")
            if seen.contains(k) { continue }
            seen.insert(k)
            out.append(Notif(id: "trig-" + n.label.lowercased().split(separator: " ").joined(separator: "-"), label: n.label, detail: n.detail, time: n.time, when: n.when, on: true))
        }
    }
    out += [
        Notif(id: "evening", label: "Evening check-in", detail: "How did today go?", time: "21:00", on: true),
        Notif(id: "heads", label: "80% heads-up", detail: "Right after a log that passes 80% of today.", on: true),
        Notif(id: "stepeve", label: "Step-down eve", detail: "The night before your budget drops.", time: "20:00", on: true),
        Notif(id: "trial", label: "Trial reminder", detail: "Day 5 of your free trial, as promised.", on: true),
    ]
    // stable sort by time; untimed rows last
    return out.enumerated().sorted { x, y in
        let a = x.element.time ?? "99", b = y.element.time ?? "99"
        return a == b ? x.offset < y.offset : a < b
    }.map(\.element)
}

// MARK: - derived numbers

struct HistoryDay: Equatable { let d: Int; let used: Int; let budget: Int; let at: Double }

struct Derived {
    var t: Double
    var name: String
    var unit: String // "hits" | "pouches"
    var one: String // "hit" | "pouch"
    var startAmt: Int
    var dayIdx: Int
    var weekIdx: Int
    var totalWeeks: Int
    var budget: Int
    var prevBudget: Int?
    var nextBudget: Int?
    var used: Int
    var left: Int
    var over: Int
    var pctUsed: Double
    var todayLogs: [LogEntry]
    var quitAt: Double
    var daysToQuit: Int
    var free: Bool
    var progress: Double
    var history: [HistoryDay]
    var underDays: Int
    var underStreak: Int
    var moneyKept: Double
    var mgAvoided: Double
    var beaten: Int
    var hourHist: [Int]
    var daysWithLogs: Int
    var pattern: String?
    var adaptive: Bool
    var reviewWeek: Int?
    var stepDownToday: Bool
    var hour: Int
    var morningDone: Bool
    var eveningDone: CheckIn?
    var runStart: Double
    var freeMs: Double
    var bestRunDays: Int
    var slippedToday: Bool

    func unitWord(_ n: Int) -> String { n == 1 ? one : unit }
}

func fmtHour(_ h: Int) -> String {
    let x = ((h % 24) + 24) % 24
    return x == 0 ? "12 am" : x == 12 ? "12 pm" : x < 12 ? "\(x) am" : "\(x - 12) pm"
}
private func ampm(_ h: Int) -> String { (((h % 24) + 24) % 24) < 12 ? "am" : "pm" }

/// "Most hits 12–2 pm and after 9 pm": the two busiest 2-hour windows.
func describePattern(_ h: [Int], _ unit: String) -> String? {
    let total = h.reduce(0, +)
    if total == 0 { return nil }
    func win(_ i: Int) -> Int { h[i % 24] + h[(i + 1) % 24] }
    let order = Array(0..<24).enumerated().sorted { x, y in
        let a = win(x.element), b = win(y.element)
        return a == b ? x.offset < y.offset : a > b
    }.map(\.element)
    let first = order[0]
    func dist(_ i: Int) -> Int { min(abs(i - first), 24 - abs(i - first)) }
    let second = order.first { dist($0) >= 3 && Double(win($0)) >= Double(win(first)) * 0.6 }
    func label(_ i: Int) -> String {
        if i >= 20 { return "after \(fmtHour(i))" }
        if i < 5 { return "late at night" }
        let a = fmtHour(i), b = fmtHour(i + 2)
        return ampm(i) == ampm(i + 2) ? "\(a.split(separator: " ")[0])–\(b)" : "\(a)–\(b)"
    }
    var ws = [first]
    if let second { ws = [first, second].sorted { ($0 < 5 ? $0 + 24 : $0) < ($1 < 5 ? $1 + 24 : $1) } }
    return "Most \(unit) \(ws.map(label).joined(separator: " and "))"
}

func derive(_ s: AppState, _ t: Double = now()) -> Derived {
    let a = s.answers
    let unit = Calc.budgetUnit(a)
    let one = unit == "pouches" ? "pouch" : "hit"
    let startAmt = Calc.startAmount(a)
    let totalWeeks = s.budgets.count
    let quitAt = addDays(s.start, totalWeeks * 7)
    let free = t >= quitAt
    let dayIdx = dayIndex(s, t)
    let planDays = totalWeeks * 7
    let weekIdx = max(0, min(Int(floor(Double(dayIdx) / 7)), totalWeeks - 1))
    let budget = free ? 0 : (s.budgets.indices.contains(weekIdx) ? s.budgets[weekIdx] : 0)
    let prevBudget: Int? = weekIdx > 0 ? s.budgets[weekIdx - 1] : nil
    let nextBudget: Int? = weekIdx < totalWeeks - 1 ? s.budgets[weekIdx + 1] : nil

    var byDay: [Int: Int] = [:]
    var hourHist = [Int](repeating: 0, count: 24)
    for l in s.logs where l.at <= t {
        let d = dayIndex(s, l.at)
        byDay[d, default: 0] += 1
        hourHist[hourOf(l.at)] += 1
    }
    let todayKey = midnight(t)
    let todayLogs = s.logs.filter { $0.at >= todayKey && $0.at <= t }
    let used = todayLogs.count
    let left = budget - used

    var history: [HistoryDay] = []
    let lastDay = min(dayIdx, planDays - 1)
    if lastDay >= 0 {
        for d in 0...lastDay {
            let w = d / 7
            history.append(HistoryDay(d: d, used: byDay[d] ?? 0, budget: s.budgets.indices.contains(w) ? s.budgets[w] : 0, at: addDays(s.start, d)))
        }
    }
    let completed = history.filter { $0.d < dayIdx }
    let underDays = completed.filter { $0.used <= $0.budget }.count
    var underStreak = 0
    for h in completed.reversed() { if h.used <= h.budget { underStreak += 1 } else { break } }

    // money kept = (yearly/365) × days × (1 − used/start). Today counts for the part of the day gone by.
    let perDay = Double(Calc.yearlySpend(a)) / 365
    let mgDay = Double(Calc.nicotineMgPerDay(a))
    let frac = (t - todayKey) / DAY
    var keptDays = 0.0
    for h in history {
        let share = max(0, 1 - Double(h.used) / Double(startAmt))
        keptDays += h.d == dayIdx ? share * frac : share
    }
    if free { keptDays += (t - quitAt) / DAY }
    let moneyKept = perDay * keptDays
    let mgAvoided = mgDay * keptDays
    let beaten = s.cravings.filter { $0.outcome == .beaten && $0.at <= t }.count

    let daysWithLogs = byDay.count
    let pattern = daysWithLogs >= 2 ? describePattern(hourHist, unit) : nil

    let last4 = Array(completed.suffix(4))
    let overCount = last4.filter { $0.used > $0.budget }.count
    let adaptive = !free && last4.count == 4 && overCount >= 3 && nextBudget != nil && budget > 0 && !s.adaptiveDone.contains(weekIdx)

    let reviewWeek: Int? = !free && weekIdx >= 1 && dayIdx < planDays && !s.reviewed.contains(weekIdx) ? weekIdx : nil
    let stepDownToday = !free && weekIdx > 0 && dayIdx % 7 == 0 && prevBudget != nil && budget < prevBudget!

    let hour = hourOf(t)
    let k = dayKey(t)
    let morningDone = s.checkins.contains { $0.date == k && $0.kind == .morning }
    let eveningDone = s.checkins.first { $0.date == k && $0.kind == .evening }

    // free mode runs: a slip ends a run; the next run starts the following midnight
    let slips = s.slips.filter { $0.at >= quitAt && $0.at <= t }.map(\.at).sorted()
    let lastSlip = slips.last
    let runStart = lastSlip.map { max(quitAt, addDays(midnight($0), 1)) } ?? quitAt
    let freeMs = free ? max(0, t - runStart) : 0
    var best = 0.0, from = quitAt
    for sl in slips { best = max(best, sl - from); from = addDays(midnight(sl), 1) }
    best = max(best, t - from)
    let slippedToday = lastSlip.map { midnight($0) == todayKey } ?? false

    return Derived(
        t: t, name: a.name ?? "", unit: unit, one: one, startAmt: startAmt, dayIdx: dayIdx, weekIdx: weekIdx, totalWeeks: totalWeeks,
        budget: budget, prevBudget: prevBudget, nextBudget: nextBudget,
        used: used, left: left, over: max(0, -left),
        pctUsed: budget > 0 ? Double(used) / Double(budget) : (used > 0 ? 1.5 : 0), todayLogs: todayLogs,
        quitAt: quitAt, daysToQuit: max(0, Int(ceil((quitAt - t) / DAY))), free: free,
        progress: max(0, min(1, (t - s.start) / (quitAt - s.start))),
        history: history, underDays: underDays, underStreak: underStreak, moneyKept: moneyKept, mgAvoided: mgAvoided, beaten: beaten,
        hourHist: hourHist, daysWithLogs: daysWithLogs, pattern: pattern,
        adaptive: adaptive, reviewWeek: reviewWeek, stepDownToday: stepDownToday, hour: hour, morningDone: morningDone, eveningDone: eveningDone,
        runStart: runStart, freeMs: freeMs, bestRunDays: Int(floor(max(0, best) / DAY)), slippedToday: slippedToday
    )
}

/// Stats for the step-down review of week w-1.
struct WeekStats { let avg: Int; let under: Int; let days: Int; let beaten: Int; let budget: Int; let next: Int }
func weekStats(_ s: AppState, _ w: Int, _ t: Double = now()) -> WeekStats {
    let from = (w - 1) * 7
    let d = derive(s, t)
    let days = d.history.filter { $0.d >= from && $0.d < from + 7 }
    let total = days.reduce(0) { $0 + $1.used }
    let ws = addDays(s.start, from), we = addDays(s.start, from + 7)
    return WeekStats(
        avg: days.isEmpty ? 0 : Int(jsRound(Double(total) / Double(days.count))),
        under: days.filter { $0.used <= $0.budget }.count,
        days: days.count,
        beaten: s.cravings.filter { $0.outcome == .beaten && $0.at >= ws && $0.at < we }.count,
        budget: s.budgets.indices.contains(w - 1) ? s.budgets[w - 1] : 0,
        next: s.budgets.indices.contains(w) ? s.budgets[w] : 0
    )
}

// MARK: - celebrations (small, earned)

struct Celebration: Equatable { let key: String; let title: String; let sub: String }
func earned(_ s: AppState, _ d: Derived) -> [Celebration] {
    var out: [Celebration] = []
    if d.underDays >= 1 { out.append(Celebration(key: "under1", title: "First day under budget", sub: "That is the whole method, done once. Now again.")) }
    if d.underStreak >= 3 { out.append(Celebration(key: "under3-\(d.dayIdx - d.underStreak)", title: "3 days in a row under budget", sub: "You are making this look normal.")) }
    if d.beaten >= 1 { out.append(Celebration(key: "crave1", title: "First craving beaten", sub: "Now you know it passes.")) }
    var n = 10
    while n <= d.beaten { out.append(Celebration(key: "crave\(n)", title: "\(n) cravings beaten", sub: "Each one you ride out makes the next one easier to ride out.")); n += 10 }
    if d.progress >= 0.5 && !d.free { out.append(Celebration(key: "half", title: "Halfway there", sub: "Half your plan is done. \(d.daysToQuit) days to go.")) }
    if d.free && d.freeMs >= 72 * HOUR { out.append(Celebration(key: "free72", title: "72 hours nicotine-free", sub: "Nicotine is out of your body. What is left is habit, and habits fade.")) }
    if d.free && d.freeMs >= 30 * DAY { out.append(Celebration(key: "free30", title: "30 days nicotine-free", sub: "A whole month. Look how far you came.")) }
    return out.filter { !s.celebrated.contains($0.key) }
}

// MARK: - free-mode milestones (honest, general timelines)

struct Milestone: Equatable { let h: Double; let t: String; let d: String }
let MILESTONES = [
    Milestone(h: 72, t: "72 h", d: "Nicotine is out of your body"),
    Milestone(h: 14 * 24, t: "2 weeks", d: "Cravings start to fade"),
    Milestone(h: 30 * 24, t: "30 days", d: "A full month free"),
    Milestone(h: 60 * 24, t: "1–3 months", d: "Breathing tends to feel easier"),
]

func fmtMoney(_ n: Double) -> String {
    let f = NumberFormatter(); f.locale = Locale(identifier: "en_US"); f.numberStyle = .decimal; f.maximumFractionDigits = 0
    return "$" + (f.string(from: NSNumber(value: jsRound(n))) ?? "0")
}
func plural(_ n: Int, _ w: String, _ p: String? = nil) -> String { "\(n) \(n == 1 ? w : (p ?? w + "s"))" }
