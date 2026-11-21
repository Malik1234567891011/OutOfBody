import Foundation

enum Config {
    /// Superwall public API key. Empty = always the native SwiftUI paywall (pw1–pw3) + StoreKit 2.
    /// Set = Superwall paywall only when `onboarding_complete` resolves to a paywall (see PaywallGate).
    static let superwallAPIKey = "pk_iR4KQdkY0JpfW2dPPpYaP"
    static let placement = "onboarding_complete"
    /// Annual subscription, $39.99 CAD, 7-day free trial (see Resources/OutOfBody.storekit).
    static let productId = "oob_annual_3999"
    /// Weekly, $3.99 CAD, no trial, same subscription group.
    static let weeklyProductId = "oob_weekly_399"

    // MARK: Analytics. Each provider is a no-op while its key is empty.

    /// PostHog project API key (Project settings → Project API key). Empty = PostHog off.
    static let posthogAPIKey = "phc_CNfnaxxLaX4LL6Wmw5XWNzMJxsEhcWC8kBQmqcGC8ysw"
    static let posthogHost = "https://us.i.posthog.com"

    /// Meta (Facebook) App ID + Client Token (developers.facebook.com → App settings → Basic / Advanced).
    /// Empty = Meta SDK never starts. Also set META_APP_ID / META_CLIENT_TOKEN in project.yml so
    /// Info.plist carries the same values (FacebookAppID / FacebookClientToken).
    static let metaAppID = "2392672664601825"
    static let metaClientToken = "bc1f07767bfa326c14a2516377079a57"

    /// Prices used for Meta value events (CAD).
    static let annualPrice = 39.99
    static let weeklyPrice = 3.99
    static let currency = "CAD"
}
