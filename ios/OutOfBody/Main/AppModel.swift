import SwiftUI
import UIKit
import UserNotifications
import WidgetKit

enum Tab: String { case today, plan, you }
enum SosStep: String { case interrupt, breathe, pass, notyet, win, reasons, myreasons, anyway }
enum Overlay: Equatable {
    case welcome(Int)
    case sos(SosStep)
    case review
    case quitday
    case widgetguide
}

struct ToastMsg: Equatable {
    let id = UUID()
    let text: String
    let hasUndo: Bool
    static func == (a: ToastMsg, b: ToastMsg) -> Bool { a.id == b.id }
}

func haptic(_ ms: Int = 12) {
    let style: UIImpactFeedbackGenerator.FeedbackStyle = ms >= 24 ? .heavy : ms >= 14 ? .medium : .light
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}

let SCREEN_OVERLAY: [String: Overlay] = [
    "welcome1": .welcome(1), "welcome2": .welcome(2), "welcome3": .welcome(3), "welcome4": .welcome(4), "welcome5": .welcome(5),
    "sos1": .sos(.interrupt), "sos2": .sos(.breathe), "sos3": .sos(.pass), "sos4": .sos(.win),
    "reasons": .sos(.reasons), "vapeanyway": .sos(.anyway),
    "review": .review, "quitday": .quitday, "widgetguide": .widgetguide,
]
let SCREEN_SCENARIO: [String: String] = ["review": "stepdown", "quitday": "quitday", "welcome1": "day1", "welcome2": "day1", "welcome3": "day1", "welcome4": "day1", "welcome5": "day1"]

/// Fresh state right after purchase (freshState in store.ts).
func freshState(_ a: Answers, _ t: Double = now()) -> AppState {
    let budgets = Calc.plan(a)
    return AppState(
        answers: a, start: midnight(t), budgets: budgets, extraWeeks: 0,
        logs: [], cravings: [], checkins: [], slips: [],
        reasons: (a.reasons ?? []).map { r in REASONS.first { $0.id == r }?.label ?? r },
        setup: Setup(), notifsAllowed: false,
        notifs: defaultNotifs(a, budgets.first ?? 0, Calc.budgetUnit(a)),
        reviewed: [], adaptiveDone: [], quitSeen: false, welcomed: false, celebrated: [],
        signature: FileManager.default.fileExists(atPath: AppGroup.signatureURL.path) ? "signature.png" : nil,
        installAt: t
    )
}

/// The app's store + navigation (AppShell's state and `Nav` in the prototype).
@MainActor
final class AppModel: ObservableObject {
    @Published var s: AppState
    @Published var tab: Tab
    @Published var overlay: Overlay?
    @Published var toast: ToastMsg?
    @Published private var tick = 0
    let persist: Bool
    let screen: String?
    private var undo: (() -> Void)?
    private var toastTask: Task<Void, Never>?
    private var timer: Timer?
    private var saveTask: Task<Void, Never>?
    static weak var current: AppModel?
    var onErase: (() -> Void)?
    func erase() { onErase?() }

    var d: Derived { _ = tick; return derive(s) }

    init(state: AppState, persist: Bool, screen: String?, tab: Tab) {
        s = state; self.persist = persist; self.screen = screen; self.tab = tab
        if let screen, let o = SCREEN_OVERLAY[screen] { overlay = o }
        else if screen == nil {
            let d = derive(state)
            if !state.welcomed { overlay = .welcome(1) }
            else if d.free && !state.quitSeen { overlay = .quitday }
            else if d.reviewWeek != nil { overlay = .review }
        }
        AppModel.current = self
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick += 1 } }
        if persist {
            observeOutsideChanges()
            SharedStore.save(state, notify: false)
            SharedStore.reloadWidgets()
            Notifs.reschedule(state)
            // carry over the permission answered during onboarding
            UNUserNotificationCenter.current().getNotificationSettings { st in
                let ok = st.authorizationStatus == .authorized || st.authorizationStatus == .provisional
                Task { @MainActor in
                    if ok != self.s.notifsAllowed { self.update { $0.notifsAllowed = ok; if ok { $0.setup.checkins = true } } }
                }
            }
        }
    }

    // MARK: state

    func update(_ f: (inout AppState) -> Void) {
        var x = s
        f(&x)
        guard x != s else { return }
        s = x
        guard persist else { return }
        SharedStore.save(x, notify: false)
        SharedStore.reloadWidgets()
        saveTask?.cancel()
        saveTask = Task { [x] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            if !Task.isCancelled { Notifs.reschedule(x) }
        }
    }

    /// The widget / Control Center wrote to the shared file: pick it up and forward its queued events.
    func reloadFromDisk() {
        guard persist, var x = SharedStore.load() else { return }
        if !x.pending.isEmpty {
            Analytics.drainPending(&x)
            SharedStore.save(x, notify: false)
        }
        if x != s { s = x }
    }

    private func observeOutsideChanges() {
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), nil, { _, _, _, _, _ in
            DispatchQueue.main.async { AppModel.current?.reloadFromDisk() }
        }, AppGroup.changed as CFString, nil, .deliverImmediately)
    }

    // MARK: nav

    func setTab(_ t: Tab) {
        haptic(6)
        if t != tab { Analytics.track("tab_viewed", ["tab": t.rawValue]) }
        tab = t
    }

    func open(_ o: Overlay?) {
        withAnimation(Env.still ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.38)) { overlay = o }
    }

    func openSos(source: String) {
        Analytics.track("sos_opened", ["source": source])
        open(.sos(.interrupt))
    }

    func showToast(_ text: String, undo: (() -> Void)? = nil) {
        toastTask?.cancel()
        self.undo = undo
        withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.28)) { toast = ToastMsg(text: text, hasUndo: undo != nil) }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !Task.isCancelled { withAnimation(.easeOut(duration: 0.2)) { toast = nil } }
        }
    }

    func runUndo() {
        undo?(); undo = nil
        haptic(8)
        withAnimation(.easeOut(duration: 0.2)) { toast = nil }
    }

    func logHit(_ source: Source = .app) {
        haptic(18)
        var res: SharedStore.LogResult?
        update { res = SharedStore.applyLog(&$0, source: source, queueEvents: false) }
        guard let r = res else { return }
        let a = r.after
        Analytics.track("hit_logged", ["source": source.rawValue, "used": a.used, "budget": a.budget, "over": a.over > 0])
        if r.crossed80 {
            Analytics.track("budget_crossed_80", ["used": a.used, "budget": a.budget])
            if persist { SharedStore.scheduleHeadsUp(s, a) }
        }
        if r.exceeded { Analytics.track("budget_exceeded", ["used": a.used, "budget": a.budget]) }
        let id = r.id
        showToast("Logged · \(a.left >= 0 ? "\(a.left) left" : "\(a.over) over")") { [weak self] in
            self?.update { $0.logs.removeAll { $0.id == id } }
            Analytics.track("hit_undone")
        }
    }

    func askPermission() {
        Notifs.request { [weak self] ok in
            guard let self else { return }
            if ok {
                self.update { $0.notifsAllowed = true; $0.setup.checkins = true }
                Analytics.track("setup_item_completed", ["item": "checkins"])
                self.showToast("Check-ins are on")
            } else {
                // Already denied once: iOS won't ask again, so send them to Settings.
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
        }
    }

    func markSetup(_ k: WritableKeyPath<Setup, Bool>, _ name: String) {
        guard !s.setup[keyPath: k] else { return }
        update { $0.setup[keyPath: k] = true }
        Analytics.track("setup_item_completed", ["item": name])
    }

    /// outofbody://sos, outofbody://today, outofbody://plan, outofbody://you
    func handle(_ url: URL) {
        guard url.scheme == "outofbody" else { return }
        let src = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "src" }?.value ?? "link"
        switch url.host ?? "" {
        case "sos": if overlay == nil || !(overlay.map { if case .sos = $0 { return true }; return false } ?? false) { openSos(source: src) }
        case "plan": open(nil); tab = .plan
        case "you": open(nil); tab = .you
        default:
            if case .sos = overlay { open(nil) }
            tab = .today
        }
    }
}
