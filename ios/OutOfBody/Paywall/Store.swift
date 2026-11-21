import StoreKit

/// StoreKit 2 purchase of the annual plan for the native paywall.
@MainActor
final class Store: ObservableObject {
    static let shared = Store()
    @Published var products: [String: Product] = [:]
    @Published var purchasing = false
    @Published var error: String?

    func load() async {
        guard products.isEmpty else { return }
        do {
            for p in try await Product.products(for: [Config.productId, Config.weeklyProductId]) { products[p.id] = p }
        }
        catch { self.error = "Couldn't load the App Store." }
    }

    /// Returns true when the user now has access.
    func buy(_ id: String) async -> Bool {
        error = nil
        await load()
        guard let product = products[id] else { error = "The App Store isn't available right now."; return false }
        purchasing = true
        defer { purchasing = false }
        Analytics.track("purchase_started", ["product_id": id])
        do {
            switch try await product.purchase(options: [.appAccountToken(UUID(uuidString: Analytics.distinctId) ?? UUID())]) {
            case .success(let v):
                if case .verified(let t) = v {
                    await t.finish()
                    let trial = t.offerType == .introductory
                    Analytics.track("purchase_completed", ["product_id": id, "trial": trial, "price": NSDecimalNumber(decimal: product.price).doubleValue, "currency": product.priceFormatStyle.currencyCode])
                    if trial {
                        AppGroup.defaults.set(Date(), forKey: "oob.trialStart")
                        Analytics.track("trial_started", ["product_id": id])
                    }
                    return true
                }
                error = "We couldn't verify that purchase."
                Analytics.track("purchase_failed", ["product_id": id, "reason": "unverified"])
            case .pending:
                error = "Purchase pending approval."
                Analytics.track("purchase_failed", ["product_id": id, "reason": "pending"])
            case .userCancelled: Analytics.track("purchase_cancelled", ["product_id": id])
            @unknown default: break
            }
        } catch {
            self.error = error.localizedDescription
            Analytics.track("purchase_failed", ["product_id": id, "reason": error.localizedDescription])
        }
        return false
    }

    func restore() async -> Bool {
        error = nil
        try? await AppStore.sync()
        if await hasAccess() { return true }
        error = "No active subscription found."
        return false
    }

    func hasAccess() async -> Bool {
        for await r in Transaction.currentEntitlements {
            if case .verified(let t) = r, [Config.productId, Config.weeklyProductId].contains(t.productID), t.revocationDate == nil { return true }
        }
        return false
    }
}
