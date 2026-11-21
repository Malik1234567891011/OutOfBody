import Foundation
import SuperwallKit

/// Decides how onboarding ends. Nobody reaches Home without an active subscription:
/// 1. Already subscribed (StoreKit entitlement or Superwall status active) → Home.
/// 2. Superwall key set and `onboarding_complete` resolves to `.paywall` → present the Superwall paywall;
///    afterwards Home only if access is now active, else fall back to the native paywall.
/// 3. Anything else (no key, noAudienceMatch, placementNotFound, holdout, paywallNotAvailable, errors)
///    → the native 3-page SwiftUI paywall (pw1–pw3), which buys `oob_annual_3999` via StoreKit 2.
enum PaywallGate {
    static var hasSuperwall: Bool { !Config.superwallAPIKey.isEmpty }

    static func configureAtLaunch() {
        guard hasSuperwall else { return }
        // Default purchase controller: Superwall observes StoreKit 2 transactions for analytics.
        Superwall.configure(apiKey: Config.superwallAPIKey)
    }

    @MainActor
    static func hasAccess() async -> Bool {
        if await Store.shared.hasAccess() { return true }
        return hasSuperwall && Superwall.shared.subscriptionStatus.isActive
    }

    @MainActor
    static func afterReady(_ m: OnboardingModel) {
        completed(m.a)
        Task { @MainActor in
            if await hasAccess() { m.finish(); return }
            guard hasSuperwall else { m.next(); return }
            setAttributes(m.a)
            let result = await Superwall.shared.getPresentationResult(forPlacement: Config.placement)
            guard case .paywall = result else { m.next(); return } // native paywall
            let handler = PaywallPresentationHandler()
            handler.onError { _ in Task { @MainActor in m.next() } }
            handler.onSkip { _ in Task { @MainActor in m.next() } }
            handler.onDismiss { _, _ in
                Task { @MainActor in
                    Analytics.track("paywall_closed", ["page": "superwall"])
                    Analytics.askTrackingOnce()
                    if await hasAccess() { m.finish() } else if m.id == "ready" { m.next() }
                }
            }
            Superwall.shared.register(placement: Config.placement, handler: handler) {
                // Feature block can also run for non-gated paywalls: re-check access.
                Task { @MainActor in
                    if await hasAccess() { m.finish() } else if m.id == "ready" { m.next() }
                }
            }
        }
    }

    /// onboarding_completed + person properties (PostHog person, Superwall attributes, Meta CompleteRegistration).
    static func completed(_ a: Answers) {
        let d = AppGroup.defaults
        Analytics.setPerson([
            "device": a.device?.rawValue ?? "none",
            "strength": a.strength ?? 0,
            "hits_per_day": Calc.usesVape(a) ? (a.hitsPerDay ?? 0) : 0,
            "pouches_per_day": a.pouchesPerDay ?? 0,
            "dependence_level": Calc.dependence(a).label,
            "weeks": Calc.weeks(a),
            "age": a.age ?? "",
            "trigger_count": a.triggers?.count ?? 0,
            "tried": a.tried ?? "",
            "quit_date": ISO8601DateFormatter().string(from: Calc.quitDate(a)),
            "yearly_spend": Calc.yearlySpend(a),
        ])
        guard !d.bool(forKey: "oob.onboardingCompleted") else { return }
        d.set(true, forKey: "oob.onboardingCompleted")
        Analytics.track("onboarding_completed", ["device": a.device?.rawValue ?? "none", "weeks": Calc.weeks(a)])
    }

    static func setAttributes(_ a: Answers) {
        Superwall.shared.setUserAttributes([
            "name": a.name,
            "quitDate": ISO8601DateFormatter().string(from: Calc.quitDate(a)),
            "startBudget": Calc.plan(a).first ?? 0,
            "budgetUnit": Calc.budgetUnit(a),
            "yearlySpend": Calc.yearlySpend(a),
            "device": a.device?.rawValue,
            "dependence": Calc.dependence(a).label,
        ])
    }
}
