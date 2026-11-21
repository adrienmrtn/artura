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

    /// Prévient un jour avant la fin de l'essai gratuit de 3 jours.
    static func scheduleTrialEnding() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["artura.trial"])
        let content = UNMutableNotificationContent()
        content.title = "Ton essai gratuit se termine demain"
        content.body = "Tu peux continuer avec Artura Pro ou annuler en un geste."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2 * 24 * 3600, repeats: false)
        center.add(UNNotificationRequest(identifier: "artura.trial", content: content, trigger: trigger))
    }
}

// MARK: - Abonnement Artura Pro (StoreKit 2)

@MainActor
final class ProStore: ObservableObject {
    static let yearlyID = "com.vikstudios.artura.pro.yearly"
    static let monthlyID = "com.vikstudios.artura.pro.monthly"
    static let allIDs: Set<String> = [yearlyID, monthlyID]

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
