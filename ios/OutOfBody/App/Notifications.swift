import Foundation
import UIKit
import UserNotifications

/// Local notifications, all scheduled on the device from the state (APP_DESIGN.md › Notifications).
/// Rescheduled whenever the state changes; tapping one deep-links (craving check-ins open SOS).
final class Notifs: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifs()
    /// Set by the app shell: receives deep links from notification taps.
    var onOpen: ((URL) -> Void)?
    var pendingURL: URL?

    func install() { UNUserNotificationCenter.current().delegate = self }

    static func request(_ done: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
            DispatchQueue.main.async {
                Analytics.track("notification_permission", ["granted": ok])
                done(ok)
            }
        }
    }

    // MARK: scheduling

    private static func at(_ day: Double, _ hhmm: String) -> Date? {
        let p = hhmm.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2 else { return nil }
        return Calendar.current.date(bySettingHour: p[0], minute: p[1], second: 0, of: toDate(day))
    }

    private static func add(_ id: String, _ body: String, kind: String, link: String, date d: Date) {
        guard d > Date() else { return }
        let c = UNMutableNotificationContent()
        c.body = body; c.sound = .default
        c.userInfo = ["kind": kind, "link": link]
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: d)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: c, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
    }

    private static let weekdays = ["Sun": 1, "Mon": 2, "Tue": 3, "Wed": 4, "Thu": 5, "Fri": 6, "Sat": 7]

    static func reschedule(_ s: AppState) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            // keep the one-off heads-ups that are about to fire
            center.removePendingNotificationRequests(withIdentifiers: reqs.map(\.identifier).filter { !$0.hasPrefix("heads-") })
            guard s.notifsAllowed else { return }
            let t = now()
            let d = derive(s, t)
            let on = { (id: String) in s.notifs.first { $0.id == id } }
            let today = midnight(t)
            for i in 0..<7 {
                let day = addDays(today, i)
                let dd = derive(s, day + 12 * HOUR)
                if let n = on("morning"), n.on, let time = n.time, let when = at(day, time) {
                    let body = dd.free ? "Another nicotine-free day. SOS is here if you need it." : "Today's budget: \(dd.budget) \(dd.unitWord(dd.budget))."
                    add("morning-\(i)", body, kind: "morning", link: "outofbody://today", date: when)
                }
                if let n = on("evening"), n.on, let time = n.time, let when = at(day, time) {
                    add("evening-\(i)", "How did today go? Check in in 10 seconds.", kind: "evening", link: "outofbody://today", date: when)
                }
            }
            // trigger check-ins repeat at the times picked in onboarding (craving moments → SOS)
            for n in s.notifs where n.id.hasPrefix("trig-") && n.on {
                guard let time = n.time else { continue }
                let p = time.split(separator: ":").compactMap { Int($0) }
                var comps = DateComponents(hour: p[0], minute: p[1])
                if let w = n.when { comps.weekday = weekdays[w] }
                let c = UNMutableNotificationContent()
                c.body = n.detail; c.sound = .default
                c.userInfo = ["kind": n.id, "link": "outofbody://sos?src=notification"]
                center.add(UNNotificationRequest(identifier: n.id, content: c, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)))
            }
            // step-down eve: the night before the next lower budget
            if let n = on("stepeve"), n.on, let time = n.time, !d.free, let next = d.nextBudget {
                let eve = addDays(s.start, (d.weekIdx + 1) * 7 - 1)
                if let when = at(eve, time) {
                    add("stepeve", next == 0 ? "Tomorrow is your zero week. The last step. You've got this." : "Tomorrow your budget drops to \(next). You've got this.",
                        kind: "stepeve", link: "outofbody://plan", date: when)
                }
            }
            // trial reminder: day 5 of the free trial, as promised on paywall page 2
            if let n = on("trial"), n.on, let start = AppGroup.defaults.object(forKey: "oob.trialStart") as? Date,
               let day5 = Calendar.current.date(byAdding: .day, value: 5, to: start) {
                add("trial", "Your free trial ends in 2 days. Manage it anytime in Settings › Apple ID › Subscriptions.",
                    kind: "trial", link: "outofbody://you", date: day5)
            }
        }
    }

    // MARK: delegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        let kind = info["kind"] as? String ?? "unknown"
        let link = (info["link"] as? String).flatMap(URL.init(string:)) ?? URL(string: "outofbody://today")!
        await MainActor.run {
            Analytics.track("notification_opened", ["kind": kind])
            if let onOpen { onOpen(link) } else { pendingURL = link }
        }
    }
}
