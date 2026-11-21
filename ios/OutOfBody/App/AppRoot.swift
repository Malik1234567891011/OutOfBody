import AppIntents
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        #if DEBUG && targetEnvironment(simulator)
        // Simulator debug runs: mirror stdout (our [analytics] lines + PostHog's debug log) to a file the
        // tap-through can read: <App Group>/debug.log
        if ProcessInfo.processInfo.environment["OOB_STDOUT"] != "1" {
            let path = AppGroup.url.appendingPathComponent("debug.log").path
            freopen(path, "a", stdout); freopen(path, "a", stderr)
            setvbuf(stdout, nil, _IOLBF, 0)
        }
        #endif
        PaywallGate.configureAtLaunch()
        Analytics.start(launchOptions: launchOptions)
        Notifs.shared.install()
        return true
    }
}

@main
struct OutOfBodyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup { AppRoot() }
    }
}

struct OutOfBodyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogHitIntent(source: "control"), phrases: ["Log a hit in \(.applicationName)"], shortTitle: "Log a hit", systemImageName: "plus.circle")
    }
}

/// Persists "onboarding done" + the answers (Codable JSON in UserDefaults).
enum Persist {
    static let doneKey = "oob.onboardingDone"
    static let answersKey = "oob.answers"
    static var done: Bool { UserDefaults.standard.bool(forKey: doneKey) }
    static var answers: Answers? {
        UserDefaults.standard.data(forKey: answersKey).flatMap { try? JSONDecoder().decode(Answers.self, from: $0) }
    }
    static func save(_ a: Answers) {
        UserDefaults.standard.set(try? JSONEncoder().encode(a), forKey: answersKey)
        UserDefaults.standard.set(true, forKey: doneKey)
    }
    static func reset() {
        UserDefaults.standard.removeObject(forKey: answersKey)
        UserDefaults.standard.removeObject(forKey: doneKey)
    }
}

/// Which app screen an env run asks for (screenshots), else nil.
@MainActor private func envAppBoot() -> AppModel? {
    let screen = Env.screen
    let appScreen = screen.map { SCREEN_OVERLAY[$0] != nil || $0 == "none" || $0.hasPrefix("checkin") } ?? false
    guard Env.scenario != nil || appScreen else { return nil }
    let a = PRESETS[Env.preset ?? "disposable"] ?? PRESETS["disposable"]!
    let sc = Env.scenario ?? screen.flatMap { SCREEN_SCENARIO[$0] } ?? "midweek"
    guard var (st, clock) = scenario(sc, a) else { return nil }
    if screen?.hasPrefix("welcome") == true { st.welcomed = false }
    if screen == "checkin-morning" || screen == "checkin-evening" {
        let morning = screen == "checkin-morning"
        clock = midnight(clock) + (morning ? 8.33 : 21.17) * 36e5
        let k = dayKey(clock)
        st.logs = st.logs.filter { $0.at <= clock }
        st.checkins = st.checkins.filter { $0.date != k || (!morning && $0.kind == .morning) }
    }
    Clock.set(clock)
    return AppModel(state: st, persist: false, screen: screen, tab: Tab(rawValue: Env.tab ?? "today") ?? .today)
}

@MainActor
struct AppRoot: View {
    @StateObject private var onboarding = OnboardingModel()
    @State private var app: AppModel?
    @Environment(\.scenePhase) private var phase
    @State private var openedOnce = false
    @State private var wasBackground = false

    init() {
        if Env.env["OOB_RESET"] == "1" { Persist.reset(); SharedStore.erase() }
        if let m = envAppBoot() { _app = State(initialValue: m); return }
        // Screenshot / preset runs of onboarding always start in onboarding.
        let forced = Env.preset != nil || Env.screen != nil
        if !forced && Persist.done {
            let a = Persist.answers ?? Answers()
            _app = State(initialValue: AppModel(state: SharedStore.load() ?? freshState(a), persist: true, screen: nil, tab: .today))
        }
    }

    var body: some View {
        ZStack {
            if let app {
                AppShell(m: app).transition(.opacity)
            } else {
                OnboardingView(m: onboarding)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            // A lapsed/refunded subscription sends a returning user back to the paywall.
            if let a = app, a.persist, !(await PaywallGate.hasAccess()) {
                onboarding.a = a.s.answers
                onboarding.idx = onboarding.ids.firstIndex(of: "pw1") ?? 0
                app = nil
            }
        }
        .onAppear {
            onboarding.onFinish = { a in
                Persist.save(a)
                let m = AppModel(state: SharedStore.load().flatMap { $0.answers == a ? $0 : nil } ?? freshState(a), persist: true, screen: nil, tab: .today)
                wire(m)
                withAnimation(.easeInOut(duration: 0.3)) { app = m }
                Analytics.askTrackingOnce() // right after the paywall flow ends, never before
            }
            if let app { wire(app) }
        }
        .onOpenURL { url in app?.handle(url) }
        .onChange(of: phase) { _, p in
            if p == .background { wasBackground = true }
            guard p == .active, let m = app, m.persist else { return }
            m.reloadFromDisk()
            guard wasBackground || !openedOnce else { return } // not after system alerts
            openedOnce = true; wasBackground = false
            let d = m.d
            let days = Calendar.current.dateComponents([.day], from: Analytics.installAt, to: Date()).day ?? 0
            Analytics.track("app_opened", ["days_since_install": days, "plan_week": d.free ? 0 : d.weekIdx + 1, "free": d.free])
            if d.free && !m.s.quitSeen && m.overlay == nil { m.open(.quitday) }
            else if d.reviewWeek != nil && m.overlay == nil { m.open(.review) }
        }
    }

    private func wire(_ m: AppModel) {
        m.onErase = {
            Persist.reset()
            SharedStore.erase()
            SharedStore.reloadWidgets()
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            onboarding.a = Answers(); onboarding.idx = 0
            withAnimation { app = nil }
        }
        Notifs.shared.onOpen = { [weak m] url in m?.handle(url) }
        if let u = Notifs.shared.pendingURL { m.handle(u); Notifs.shared.pendingURL = nil }
    }
}
