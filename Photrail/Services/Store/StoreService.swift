import Foundation
import StoreKit

/// The single point of contact with StoreKit. Owns the "Photrail Lifetime" non-consumable
/// entitlement: loads the product, drives purchase/restore, listens for async transaction
/// updates (refunds, Family Sharing), and resolves the one-time grandfathering of users who
/// bought the app back when it was paid-upfront.
///
/// Entitlement is cached to the App Group so it reads instantly and **offline**, and so the
/// widget extension can see it. StoreKit is the source of truth when reachable; we never
/// *revoke* on a transient network failure.
@MainActor
@Observable
final class StoreService {

    /// Must match the non-consumable IAP id in App Store Connect.
    static let productID = "Berend.Photrail.lifetime"

    /// iOS `AppTransaction.originalAppVersion` is the ORIGINAL BUILD NUMBER (CFBundleVersion),
    /// not the marketing version. Every paid-upfront build shipped with build ≤ 6; the first
    /// freemium build is 7. So anyone whose original build ≤ 6 paid before and is grandfathered.
    static let grandfatherMaxBuild = 6

    // MARK: - Observable state

    private(set) var product: Product?
    /// True when StoreKit reports a current entitlement to the lifetime product.
    private(set) var purchased = false
    /// True when the user originally bought the paid-upfront app.
    private(set) var grandfathered = false
    /// A purchase or restore is in flight (drives button spinners).
    private(set) var working = false

    /// Final entitlement. Either path unlocks everything.
    var hasLifetime: Bool { purchased || grandfathered }

    /// Localized price for the CTA. Falls back to a sensible default before the product loads.
    var displayPrice: String { product?.displayPrice ?? "€2.99" }

    /// Invoked on the main actor whenever the entitlement may have changed, so the owner can
    /// republish widget stats etc.
    var onEntitlementChange: (@MainActor () -> Void)?

    // MARK: - Persistence (App Group so widgets + offline reads work)

    private static let cachedPurchasedKey = "hasLifetimeCached"
    private static let grandfatheredKey = "grandfathered"
    private static let grandfatherResolvedKey = "grandfatherResolved"

    private var groupDefaults: UserDefaults? { UserDefaults(suiteName: WidgetSharedStore.appGroup) }

    private var updatesTask: Task<Void, Never>?

    init() {
        // Seed from cache immediately for an instant, offline-correct first read.
        purchased = groupDefaults?.bool(forKey: Self.cachedPurchasedKey) ?? false
        grandfathered = groupDefaults?.bool(forKey: Self.grandfatheredKey) ?? false
        updatesTask = listenForTransactions()
    }

    /// Full refresh: load the product, re-evaluate entitlements, resolve grandfathering.
    /// Safe to call on every launch. Never revokes on network failure.
    func start() async {
        await loadProduct()
        await refreshEntitlements()
        await checkGrandfather()
    }

    // MARK: - Product

    func loadProduct() async {
        product = try? await Product.products(for: [Self.productID]).first
    }

    // MARK: - Entitlements

    /// Re-evaluate `Transaction.currentEntitlements`. Only flips `purchased` to true when a
    /// verified, non-revoked lifetime transaction is present; caches the result.
    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.productID, transaction.revocationDate == nil {
                owned = true
            }
        }
        setPurchased(owned)
    }

    /// One-time grandfathering. Reads the app's original purchase build via `AppTransaction`.
    /// If the network is unavailable it silently no-ops and retries on the next launch.
    func checkGrandfather() async {
        if groupDefaults?.bool(forKey: Self.grandfatherResolvedKey) == true { return }
        guard let result = try? await AppTransaction.shared,
              case .verified(let appTransaction) = result else {
            return   // no network / unverifiable — try again next launch
        }
        if let build = Int(appTransaction.originalAppVersion), build <= Self.grandfatherMaxBuild {
            setGrandfathered(true)
        }
        groupDefaults?.set(true, forKey: Self.grandfatherResolvedKey)
    }

    // MARK: - Purchase / restore

    /// Buy Lifetime. Returns true on a verified success. Silently returns false on cancel,
    /// pending (e.g. Ask to Buy), or failure.
    @discardableResult
    func purchase() async -> Bool {
        if product == nil { await loadProduct() }
        guard let product else { return false }
        working = true
        defer { working = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return false }
                setPurchased(true)
                await transaction.finish()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    /// Restore purchases (required by App Review). Syncs with the App Store then re-checks.
    func restore() async {
        working = true
        defer { working = false }
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Internals

    private func setPurchased(_ value: Bool) {
        purchased = value
        groupDefaults?.set(value, forKey: Self.cachedPurchasedKey)
        onEntitlementChange?()
    }

    private func setGrandfathered(_ value: Bool) {
        grandfathered = value
        groupDefaults?.set(value, forKey: Self.grandfatheredKey)
        onEntitlementChange?()
    }

    /// Listen for out-of-band transaction changes (Family Sharing, refunds, purchases made on
    /// another device) and re-evaluate entitlements.
    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { continue }
                if case .verified(let transaction) = update {
                    await self.refreshEntitlements()
                    await transaction.finish()
                }
            }
        }
    }
}
