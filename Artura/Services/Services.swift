import Foundation
import StoreKit
import UserNotifications

// MARK: - Rappels

enum Reminder {
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Programme la notification quotidienne à l'heure choisie (minutes depuis minuit).
    static func scheduleDaily(atMinutes minutes: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["artura.daily"])
        let content = UNMutableNotificationContent()
        content.title = "Ton œuvre du jour t'attend"
        content.body = "Cinq minutes pour regarder, comprendre et retenir."
        content.sound = .default
        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: "artura.daily", content: content, trigger: trigger))
    }

    static func cancelDaily() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["artura.daily"])
    }

    /// Prévient un jour avant la fin de l'essai gratuit (3 jours par défaut).
    static func scheduleTrialEnding(trialDays: Int = 3) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["artura.trial"])
        let content = UNMutableNotificationContent()
        content.title = "Ton essai gratuit se termine demain"
        content.body = "Tu peux continuer avec Artura Pro ou annuler en un geste."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(max(1, trialDays - 1)) * 24 * 3600, repeats: false)
        center.add(UNNotificationRequest(identifier: "artura.trial", content: content, trigger: trigger))
    }
}

// MARK: - Abonnement Artura Pro (StoreKit 2)

@MainActor
final class ProStore: ObservableObject {
    static let yearlyID = "com.vikstudios.artura.pro.yearly"
    static let monthlyID = "com.vikstudios.artura.pro.monthly"
    /// Même abonnement annuel, avec 7 jours d'essai au lieu de 3 (offre de dernière minute).
    static let yearlyExtendedID = "com.vikstudios.artura.pro.yearly.trial7"
    static let allIDs: Set<String> = [yearlyID, monthlyID, yearlyExtendedID]

    @Published var products: [Product] = []
    @Published var isPro = false
    @Published var isPurchasing = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
        Task { [weak self] in
            await self?.loadProducts()
            await self?.refreshEntitlements()
        }
    }

    var yearly: Product? { products.first { $0.id == Self.yearlyID } }
    var monthly: Product? { products.first { $0.id == Self.monthlyID } }
    var yearlyExtended: Product? { products.first { $0.id == Self.yearlyExtendedID } }

    func loadProducts() async {
        do {
            products = try await Product.products(for: Self.allIDs)
        } catch {
            lastError = "Impossible de charger les offres."
        }
    }

    func refreshEntitlements() async {
        var pro = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               Self.allIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                pro = true
            }
        }
        isPro = pro
    }

    /// Lance l'achat. Retourne true si l'abonnement est actif à la fin.
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                    return true
                }
                lastError = "L'achat n'a pas pu être vérifié."
                return false
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = "L'achat a échoué. Réessaie dans un instant."
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }
}

extension Product {
    /// Durée de l'essai gratuit en jours, lue sur l'offre de lancement du produit.
    var trialDays: Int? {
        guard let offer = subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        let count = offer.period.value * offer.periodCount
        switch offer.period.unit {
        case .day: return count
        case .week: return count * 7
        case .month: return count * 30
        case .year: return count * 365
        @unknown default: return nil
        }
    }
}

/// Ce que les écrans d'essai gratuit affichent : prix et durée, lus sur le produit StoreKit.
struct TrialOffer {
    let product: Product?
    let trialDays: Int
    /// "29,99 €"
    let yearlyPrice: String
    /// "2,50 €"
    let monthlyPrice: String
    /// "0,00 €"
    let zeroPrice: String

    init?(_ product: Product?) {
        guard let product, let days = product.trialDays else { return nil }
        self.product = product
        trialDays = days
        yearlyPrice = product.displayPrice
        monthlyPrice = (product.price / 12).formatted(product.priceFormatStyle)
        zeroPrice = Decimal(0).formatted(product.priceFormatStyle)
    }

    #if DEBUG
    /// Valeurs d'exemple pour afficher les écrans sans StoreKit (captures d'écran, aperçus).
    init(previewDays: Int) {
        product = nil
        trialDays = previewDays
        yearlyPrice = "29,99 €"
        monthlyPrice = "2,50 €"
        zeroPrice = "0,00 €"
    }
    #endif
}
