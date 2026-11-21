import Foundation
import StoreKit
import UserNotifications

// MARK: - Reminders

enum Reminder {
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Schedules the daily notification at the chosen time (minutes since midnight).
    static func scheduleDaily(atMinutes minutes: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["artura.daily"])
        let content = UNMutableNotificationContent()
        content.title = "Your artwork of the day is waiting"
        content.body = "Five minutes to look, understand, and remember."
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

    /// Notifies one day before the free trial ends (3 days by default).
    static func scheduleTrialEnding(trialDays: Int = 3) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["artura.trial"])
        let content = UNMutableNotificationContent()
        content.title = "Your free trial ends tomorrow"
        content.body = "Keep going with Artura Pro, or cancel in one tap."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(max(1, trialDays - 1)) * 24 * 3600, repeats: false)
        center.add(UNNotificationRequest(identifier: "artura.trial", content: content, trigger: trigger))
    }
}

// MARK: - Artura Pro subscription (StoreKit 2)

@MainActor
final class ProStore: ObservableObject {
    static let yearlyID = "com.vikstudios.artura.pro.yearly"
    static let monthlyID = "com.vikstudios.artura.pro.monthly"
    /// Same yearly subscription, with a 7-day trial instead of 3 (last-minute offer).
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
            lastError = "Couldn't load the plans."
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

    /// Starts the purchase. Returns true if the subscription is active at the end.
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
                lastError = "The purchase couldn't be verified."
                return false
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = "The purchase failed. Try again in a moment."
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }
}

extension Product {
    /// Length of the free trial in days, read from the product's introductory offer.
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

/// What the free trial screens display: price and duration, read from the StoreKit product.
struct TrialOffer {
    let product: Product?
    let trialDays: Int
    /// "$29.99"
    let yearlyPrice: String
    /// "$2.50"
    let monthlyPrice: String
    /// "$0.00"
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
    /// Sample values to show the screens without StoreKit (screenshots, previews).
    init(previewDays: Int) {
        product = nil
        trialDays = previewDays
        yearlyPrice = "$29.99"
        monthlyPrice = "$2.50"
        zeroPrice = "$0.00"
    }
    #endif
}
