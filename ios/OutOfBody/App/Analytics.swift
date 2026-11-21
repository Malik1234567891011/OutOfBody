import AppTrackingTransparency
import FacebookCore
import Foundation
import PostHog
import SuperwallKit

/// One call site per event: `Analytics.track("hit_logged", [...])` fans out to every provider.
/// PostHog and Meta are no-ops while their keys in Config.swift are empty. DEBUG prints every event.
enum Analytics {
    private static var started = false
    private static var posthogOn: Bool { !Config.posthogAPIKey.isEmpty }
    private static var metaOn: Bool { !Config.metaAppID.isEmpty }

    /// Stable anonymous id, kept in the App Group so the app and widgets agree. Shared with Superwall
    /// (identify) and PostHog (distinct id) so the two join.
    static var distinctId: String {
        let d = AppGroup.defaults
        if let id = d.string(forKey: "oob.distinctId") { return id }
        let id = UUID().uuidString.lowercased()
        d.set(id, forKey: "oob.distinctId")
        return id
    }
    static var installAt: Date {
        let d = AppGroup.defaults
        if let t = d.object(forKey: "oob.installAt") as? Date { return t }
        d.set(Date(), forKey: "oob.installAt")
        return Date()
    }

    static func start(launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) {
        guard !started else { return }
        started = true
        _ = installAt
        let id = distinctId
        if posthogOn {
            let c = PostHogConfig(projectToken: Config.posthogAPIKey, host: Config.posthogHost)
            c.captureScreenViews = false // we send our own screen events
            c.captureApplicationLifecycleEvents = true
            #if DEBUG
            c.debug = true // logs each batch upload so a tap-through can confirm delivery
            c.flushAt = 5
            #endif
            PostHogSDK.shared.setup(c)
            PostHogSDK.shared.identify(id)
        }
        if metaOn {
            Settings.shared.appID = Config.metaAppID
            Settings.shared.clientToken = Config.metaClientToken
            Settings.shared.displayName = "OutOfBody"
            Settings.shared.isAutoLogAppEventsEnabled = true // fb_mobile_activate_app is automatic
            Settings.shared.isAdvertiserIDCollectionEnabled = ATTrackingManager.trackingAuthorizationStatus == .authorized
            ApplicationDelegate.shared.application(UIApplication.shared, didFinishLaunchingWithOptions: launchOptions)
            AppEvents.shared.userID = id
        }
        if PaywallGate.hasSuperwall { Superwall.shared.identify(userId: id) }
    }

    static func track(_ name: String, _ props: [String: Any] = [:]) {
        #if DEBUG
        let p = props.keys.sorted().map { "\($0)=\(props[$0]!)" }.joined(separator: " ")
        print("[analytics] \(name) \(p)")
        #endif
        if posthogOn { PostHogSDK.shared.capture(name, properties: props) }
        if metaOn { meta(name, props) }
    }

    /// Person properties (set once onboarding is done).
    static func setPerson(_ props: [String: Any]) {
        #if DEBUG
        print("[analytics] $set \(props.keys.sorted().map { "\($0)=\(props[$0]!)" }.joined(separator: " "))")
        #endif
        if posthogOn { PostHogSDK.shared.identify(distinctId, userProperties: props) }
        if PaywallGate.hasSuperwall { Superwall.shared.setUserAttributes(props) }
    }

    /// Meta: only the registration event is manual; activate_app and purchases are automatic.
    private static func meta(_ name: String, _ p: [String: Any]) {
        switch name {
        case "onboarding_completed":
            AppEvents.shared.logEvent(.completedRegistration, parameters: [.registrationMethod: "onboarding"])
        // StartTrial / Subscribe / Purchase are NOT logged here: the Meta app has automatic in-app
        // event logging on, which reports them from StoreKit. Logging them too would double count.
        default: break
        }
    }

    // MARK: - App Tracking Transparency (asked once, right after the paywall flow ends)

    static func askTrackingOnce() {
        let d = AppGroup.defaults
        guard !d.bool(forKey: "oob.attAsked") else { return }
        d.set(true, forKey: "oob.attAsked")
        // The system prompt only shows while the app is active; give the paywall a moment to leave.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            ATTrackingManager.requestTrackingAuthorization { st in
                let s: String
                switch st {
                case .authorized: s = "authorized"
                case .denied: s = "denied"
                case .restricted: s = "restricted"
                default: s = "not_determined"
                }
                DispatchQueue.main.async {
                    if metaOn { Settings.shared.isAdvertiserIDCollectionEnabled = st == .authorized }
                    track("att_result", ["status": s])
                }
            }
        }
    }

    /// Events the widgets / Control Center queued while the app was closed.
    static func drainPending(_ s: inout AppState) {
        for e in s.pending { var p: [String: Any] = e.props; p["queued"] = true; track(e.name, p) }
        s.pending = []
    }
}
