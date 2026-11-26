import Foundation
import StoreKit
import RevenueCat

/// Sends the app's StoreKit 2 purchases to RevenueCat, for its dashboard (trials, revenue, renewals).
/// Purchases are still made and finished by `ProStore`; RevenueCat only records them
/// (`purchasesAreCompletedBy: .myApp`), so the subscription keeps working if RevenueCat is unreachable.
/// Kept in its own file so that RevenueCat's type names don't clash with StoreKit's elsewhere.
enum RevenueCatBridge {
    /// Public SDK key of the "Artura iOS" app in the RevenueCat project "Artura" (safe to ship in the app).
    private static let apiKey = "appl_icLRaBpMpgZTorveSRVsiEXGFSe"
    /// Set once the purchases made before RevenueCat was added (versions 2.0 to 2.2) have been sent.
    private static let syncedKey = "revenueCatSyncedExistingPurchases"

    static func configure() {
        guard !Purchases.isConfigured else { return }
        Purchases.logLevel = .warn
        Purchases.configure(
            with: Configuration.Builder(withAPIKey: apiKey)
                .with(purchasesAreCompletedBy: .myApp, storeKitVersion: .storeKit2)
                .build()
        )
    }

    /// Records a purchase made with StoreKit 2, right after `product.purchase()`.
    static func record(_ result: StoreKit.Product.PurchaseResult) async {
        guard Purchases.isConfigured else { return }
        _ = try? await Purchases.shared.recordPurchase(result)
    }

    /// Sends the subscriptions bought before RevenueCat was in the app, once per install.
    static func syncExistingPurchasesOnce() async {
        guard Purchases.isConfigured, !UserDefaults.standard.bool(forKey: syncedKey) else { return }
        do {
            _ = try await Purchases.shared.syncPurchases()
            UserDefaults.standard.set(true, forKey: syncedKey)
        } catch {
            // Tried again at the next launch.
        }
    }

    /// After "Restore purchases": lets RevenueCat see the restored subscription too.
    static func syncAfterRestore() async {
        guard Purchases.isConfigured else { return }
        _ = try? await Purchases.shared.syncPurchases()
    }
}
