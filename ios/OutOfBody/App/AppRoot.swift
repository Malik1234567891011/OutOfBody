import SwiftUI

@main
struct OutOfBodyApp: App {
    init() { PaywallGate.configureAtLaunch() }
    var body: some Scene {
        WindowGroup { AppRoot() }
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

struct AppRoot: View {
    @StateObject private var model = OnboardingModel()
    @State private var home: Answers?

    init() {
        // Screenshot / preset runs always start in onboarding.
        if Env.env["OOB_RESET"] == "1" { Persist.reset() }
        let forced = Env.preset != nil || Env.screen != nil
        _home = State(initialValue: !forced && Persist.done ? (Persist.answers ?? Answers()) : nil)
    }

    var body: some View {
        ZStack {
            if let home {
                HomeView(a: home).transition(.opacity)
            } else {
                OnboardingView(m: model)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            // A lapsed/refunded subscription sends a returning user back to the paywall.
            if let h = home, !(await PaywallGate.hasAccess()) {
                model.a = h
                model.idx = model.ids.firstIndex(of: "pw1") ?? 0
                home = nil
            }
        }
        .onAppear {
            model.onFinish = { a in
                Persist.save(a)
                withAnimation(.easeInOut(duration: 0.3)) { home = a }
            }
        }
    }
}
