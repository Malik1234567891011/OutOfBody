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
}
