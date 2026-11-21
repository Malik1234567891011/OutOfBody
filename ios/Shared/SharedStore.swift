import Foundation
import UserNotifications
#if canImport(WidgetKit)
import WidgetKit
#endif

/// The App Group container both the app and the widgets extension read and write.
enum AppGroup {
    static let id = "group.com.malikshourbaji.outofbody"
    static var url: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    static var defaults: UserDefaults { UserDefaults(suiteName: id) ?? .standard }
    static var stateURL: URL { url.appendingPathComponent("state.json") }
    static var signatureURL: URL { url.appendingPathComponent("signature.png") }
    /// Posted (Darwin, cross-process) whenever the shared state file changes.
    static let changed = "com.malikshourbaji.outofbody.changed"
}

enum SharedStore {
    static func load() -> AppState? {
        var out: AppState?
        coordinate(write: false) { url in
            guard let data = try? Data(contentsOf: url) else { return }
            out = try? JSONDecoder().decode(AppState.self, from: data)
        }
        return out?.v == 1 ? out : nil
    }

    static func save(_ s: AppState, notify: Bool = true) {
        guard let data = try? JSONEncoder().encode(s) else { return }
        coordinate(write: true) { url in try? data.write(to: url, options: .atomic) }
        if notify { postChanged() }
    }

    static func erase() {
        try? FileManager.default.removeItem(at: AppGroup.stateURL)
        try? FileManager.default.removeItem(at: AppGroup.signatureURL)
    }

    /// Read-modify-write under one file coordination (safe against the widget writing at the same time).
    @discardableResult
    static func mutate(_ f: (inout AppState) -> Void) -> AppState? {
        var result: AppState?
        let c = NSFileCoordinator()
        var err: NSError?
        c.coordinate(writingItemAt: AppGroup.stateURL, options: .forMerging, error: &err) { url in
            guard let data = try? Data(contentsOf: url), var s = try? JSONDecoder().decode(AppState.self, from: data) else { return }
            f(&s)
            if let out = try? JSONEncoder().encode(s) { try? out.write(to: url, options: .atomic) }
            result = s
        }
        if result != nil { postChanged() }
        return result
    }

    private static func coordinate(write: Bool, _ f: (URL) -> Void) {
        let c = NSFileCoordinator()
        var err: NSError?
        if write { c.coordinate(writingItemAt: AppGroup.stateURL, options: .forReplacing, error: &err, byAccessor: f) }
        else { c.coordinate(readingItemAt: AppGroup.stateURL, options: [], error: &err, byAccessor: f) }
    }

    static func postChanged() {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(AppGroup.changed as CFString), nil, nil, true)
    }

    static func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    // MARK: - logging a hit (shared by the in-app button, widgets, Control Center and Action Button)

    struct LogResult { let id: String; let before: Derived; let after: Derived; let crossed80: Bool; let exceeded: Bool }

    /// Pure state change: appends the log and returns what changed. `queueEvents` stores the analytics
    /// events for the app to forward later (used when logging from outside the app).
    static func applyLog(_ s: inout AppState, source: Source, at t: Double = now(), queueEvents: Bool) -> LogResult {
        let before = derive(s, t)
        let id = uid()
        s.logs.append(LogEntry(id: id, at: t, source: source))
        let after = derive(s, t)
        let b0 = before.budget > 0 ? Double(before.used) / Double(before.budget) : 1
        let b1 = after.budget > 0 ? Double(after.used) / Double(after.budget) : 1
        let crossed80 = before.budget > 0 && b0 < 0.8 && b1 >= 0.8 && b1 <= 1
        let exceeded = after.budget > 0 && before.used <= before.budget && after.used > after.budget
        if queueEvents {
            s.pending.append(PendingEvent(name: "hit_logged", props: ["source": source.rawValue, "used": "\(after.used)", "budget": "\(after.budget)", "over": "\(after.over > 0)"], at: t))
            if crossed80 { s.pending.append(PendingEvent(name: "budget_crossed_80", props: ["used": "\(after.used)", "budget": "\(after.budget)"], at: t)) }
            if exceeded { s.pending.append(PendingEvent(name: "budget_exceeded", props: ["used": "\(after.used)", "budget": "\(after.budget)"], at: t)) }
            s.pending = Array(s.pending.suffix(200))
        }
        return LogResult(id: id, before: before, after: after, crossed80: crossed80, exceeded: exceeded)
    }

    /// Log from outside the app process (widget / control / intent). Writes the file, schedules the
    /// 80% heads-up when it applies, and reloads widget timelines.
    @discardableResult
    static func logFromOutside(source: Source) -> LogResult? {
        var res: LogResult?
        let s = mutate { st in res = applyLog(&st, source: source, queueEvents: true) }
        if let s, let r = res, r.crossed80 { scheduleHeadsUp(s, r.after) }
        reloadWidgets()
        return res
    }

    /// "You've used 83% of today's budget. 4 left. Spread them out." — right after the log that crosses 80%.
    static func scheduleHeadsUp(_ s: AppState, _ d: Derived) {
        guard s.notifsAllowed, s.notifs.first(where: { $0.id == "heads" })?.on ?? false else { return }
        let c = UNMutableNotificationContent()
        c.body = "You've used \(Int(jsRound(d.pctUsed * 100)))% of today's budget. \(d.left) left. Spread them out."
        c.sound = .default
        c.userInfo = ["kind": "heads", "link": "outofbody://today"]
        let req = UNNotificationRequest(identifier: "heads-\(uid())", content: c, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
        UNUserNotificationCenter.current().add(req)
    }
}
