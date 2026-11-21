import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct OOBEntry: TimelineEntry {
    let date: Date
    let ready: Bool // false until the plan exists (before purchase)
    let budget: Int
    let used: Int
    let left: Int
    let over: Int
    let one: String
    let unit: String
    let free: Bool
    let freeDays: Int
    let week: [(used: Int, budget: Int, today: Bool)]

    var frac: Double { over > 0 ? min(1, Double(over) / Double(max(1, budget))) : budget > 0 ? Double(max(0, left)) / Double(budget) : 0 }
    var color: Color {
        if over > 0 || (budget == 0 && used > 0) { return T.danger }
        if budget > 0 && Double(left) / Double(budget) < 0.3 { return T.warn }
        return T.accent
    }
    var big: String { free ? "\(freeDays)" : over > 0 ? "+\(over)" : "\(max(0, left))" }
    var caption: String { free ? (freeDays == 1 ? "day free" : "days free") : over > 0 ? "over" : "\(left == 1 ? one : unit) left" }

    static func from(_ s: AppState?, at t: Double = now()) -> OOBEntry {
        guard let s else {
            return OOBEntry(date: toDate(t), ready: false, budget: 23, used: 9, left: 14, over: 0, one: "hit", unit: "hits", free: false, freeDays: 0, week: [])
        }
        let d = derive(s, t)
        let first = max(0, d.dayIdx - 6)
        let week = (first..<(first + 7)).map { i -> (Int, Int, Bool) in
            let h = d.history.first { $0.d == i }
            let w = i / 7
            return (h?.used ?? 0, s.budgets.indices.contains(w) ? s.budgets[w] : 0, i == d.dayIdx)
        }
        return OOBEntry(date: toDate(t), ready: true, budget: d.budget, used: d.used, left: d.left, over: d.over, one: d.one, unit: d.unit,
                        free: d.free, freeDays: Int(d.freeMs / DAY), week: week)
    }
    static let sample = OOBEntry(date: Date(), ready: true, budget: 23, used: 9, left: 14, over: 0, one: "hit", unit: "hits", free: false, freeDays: 0,
                                 week: [(22, 23, false), (25, 23, false), (20, 23, false), (21, 23, false), (19, 23, false), (23, 23, false), (9, 23, true)])
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> OOBEntry { .sample }
    func getSnapshot(in context: Context, completion: @escaping (OOBEntry) -> Void) {
        completion(context.isPreview ? (SharedStore.load().map { OOBEntry.from($0) } ?? .sample) : OOBEntry.from(SharedStore.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<OOBEntry>) -> Void) {
        let s = SharedStore.load()
        let t = now()
        // refresh at midnight (new budget) and hourly (free-mode counter, step-down days)
        let nextHour = ms(Calendar.current.nextDate(after: toDate(t), matching: DateComponents(minute: 0), matchingPolicy: .nextTime) ?? toDate(t + HOUR))
        let entries = [OOBEntry.from(s, at: t), OOBEntry.from(s, at: nextHour)]
        completion(Timeline(entries: entries, policy: .after(toDate(nextHour + HOUR))))
    }
}

// MARK: - Pieces

struct WRing: View {
    let frac: Double
    let color: Color
    var track: Color = .white.opacity(0.1)
    let width: CGFloat
    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: width)
            Circle().trim(from: 0, to: max(0.001, frac))
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .opacity(frac <= 0 ? 0 : 1)
        }
        .padding(width / 2)
    }
}

struct PlusButton: View {
    var size: CGFloat = 36
    var body: some View {
        Button(intent: LogHitIntent(source: "widget")) {
            Image(systemName: "plus").font(.system(size: size * 0.45, weight: .bold)).foregroundStyle(T.accentInk)
                .frame(width: size, height: size).background(Circle().fill(T.accent))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lock screen

struct CircularView: View {
    let e: OOBEntry
    var body: some View {
        Button(intent: LogHitIntent(source: "widget")) {
            ZStack {
                AccessoryWidgetBackground()
                WRing(frac: e.free ? 1 : e.frac, color: .white, track: .white.opacity(0.25), width: 5)
                VStack(spacing: -2) {
                    Text(e.big).font(.system(size: 17, weight: .bold)).monospacedDigit().minimumScaleFactor(0.6)
                    Text(e.free ? "free" : e.over > 0 ? "over" : "left").font(.system(size: 9, weight: .semibold)).opacity(0.75)
                }
            }
        }
        .buttonStyle(.plain)
        .widgetAccentable()
    }
}

struct RectView: View {
    let e: OOBEntry
    var body: some View {
        Button(intent: LogHitIntent(source: "widget")) {
            HStack(spacing: 10) {
                ZStack {
                    WRing(frac: e.free ? 1 : e.frac, color: .white, track: .white.opacity(0.25), width: 4.5)
                    Text(e.free ? "✓" : e.over > 0 ? "+\(e.over)" : "\(max(0, e.left))").font(.system(size: 13, weight: .heavy)).monospacedDigit().minimumScaleFactor(0.6)
                }
                .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 0) {
                    Text(e.free ? "Day \(e.freeDays) free" : e.over > 0 ? "\(e.over) over" : "\(max(0, e.left)) left")
                        .font(.system(size: 17, weight: .bold)).monospacedDigit()
                    Text(e.free ? "nicotine-free" : "tap to log").font(.system(size: 12.5)).opacity(0.72)
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .widgetAccentable()
    }
}

// MARK: - Home screen

struct SmallView: View {
    let e: OOBEntry
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    WRing(frac: e.free ? 1 : e.frac, color: e.free ? T.accent : e.color, width: 11)
                    VStack(spacing: 0) {
                        Text(e.big).font(.system(size: 34, weight: .heavy)).tracking(-1).monospacedDigit().foregroundStyle(e.over > 0 ? T.danger : T.text)
                            .minimumScaleFactor(0.6).lineLimit(1)
                        Text(e.caption).font(.system(size: 10.5, weight: .medium)).foregroundStyle(T.muted)
                    }
                }
                .frame(width: 104, height: 104)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            if !e.free { PlusButton(size: 38) }
        }
        .widgetURL(URL(string: "outofbody://today?src=widget"))
    }
}

struct MediumView: View {
    let e: OOBEntry
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                WRing(frac: e.free ? 1 : e.frac, color: e.free ? T.accent : e.color, width: 11)
                VStack(spacing: 0) {
                    Text(e.big).font(.system(size: 34, weight: .heavy)).tracking(-1).monospacedDigit().foregroundStyle(e.over > 0 ? T.danger : T.text)
                        .minimumScaleFactor(0.6).lineLimit(1)
                    Text(e.caption).font(.system(size: 10.5, weight: .medium)).foregroundStyle(T.muted)
                }
            }
            .frame(width: 120, height: 120)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(e.free ? "Nicotine-free" : "This week").font(.system(size: 13, weight: .semibold)).foregroundStyle(T.muted)
                    Spacer()
                    if !e.free { PlusButton(size: 30) }
                }
                WeekBars(week: e.week)
                Link(destination: URL(string: "outofbody://sos?src=widget")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "wind").font(.system(size: 13, weight: .bold))
                        Text("SOS").font(.system(size: 14, weight: .heavy))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 32)
                    .background(Capsule().fill(T.danger))
                }
            }
        }
        .widgetURL(URL(string: "outofbody://today?src=widget"))
    }
}

struct WeekBars: View {
    let week: [(used: Int, budget: Int, today: Bool)]
    var body: some View {
        let mx = max(4, week.map { max($0.used, $0.budget) }.max() ?? 4)
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(Array(week.enumerated()), id: \.offset) { _, x in
                RoundedRectangle(cornerRadius: 3)
                    .fill(x.used > x.budget ? T.danger : T.accent)
                    .opacity(x.today ? 0.6 : 1)
                    .frame(height: max(3, CGFloat(x.used) / CGFloat(mx) * 40))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 40, alignment: .bottom)
    }
}

// MARK: - Widgets

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "OOBToday", provider: Provider()) { e in
            TodayWidgetView(e: e).containerBackground(for: .widget) { T.bg }
        }
        .configurationDisplayName("Today")
        .description("Hits left today. Tap + to log one.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) var family
    let e: OOBEntry
    var body: some View {
        switch family {
        case .systemMedium: MediumView(e: e)
        default: SmallView(e: e)
        }
    }
}

struct LockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "OOBLock", provider: Provider()) { e in
            LockWidgetView(e: e).containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Log a hit")
        .description("Tap to log. No unlocking.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct LockWidgetView: View {
    @Environment(\.widgetFamily) var family
    let e: OOBEntry
    var body: some View {
        switch family {
        case .accessoryRectangular: RectView(e: e)
        default: CircularView(e: e)
        }
    }
}

@available(iOS 18.0, *)
struct LogHitControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.malikshourbaji.outofbody.loghit") {
            ControlWidgetButton(action: LogHitIntent(source: "control")) {
                Label("Log a hit", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Log a hit")
        .description("Adds one to today's count.")
    }
}

@main
struct OOBWidgets: WidgetBundle {
    var body: some Widget {
        LockWidget()
        TodayWidget()
        if #available(iOS 18.0, *) { LogHitControl() }
    }
}
