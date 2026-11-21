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
        do {
            switch try await product.purchase() {
            case .success(let v):
                if case .verified(let t) = v { await t.finish(); return true }
                error = "We couldn't verify that purchase."
            case .pending: error = "Purchase pending approval."
            case .userCancelled: break
            @unknown default: break
            }
        } catch { self.error = error.localizedDescription }
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
