package com.vikstudios.artura.services

import android.content.Context
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesAreCompletedBy
import com.revenuecat.purchases.PurchasesConfiguration

/**
 * Sends the app's Google Play purchases to RevenueCat, for its dashboard (trials, revenue, renewals).
 * Purchases are still made and acknowledged by [ProStore]; RevenueCat only records them
 * (`PurchasesAreCompletedBy.MY_APP`), so the subscription keeps working if RevenueCat is unreachable.
 */
object RevenueCatBridge {
    /** Public SDK key of the "Artura Android" app in the RevenueCat project "Artura" (safe to ship in the app). */
    private const val API_KEY = "goog_nrVcIMovLxiNUFoLqyLtpSaskgk"
    private const val PREFS = "revenuecat"
    /** Set once the purchases made before RevenueCat was added have been sent. */
    private const val SYNCED = "synced_existing_purchases"

    private lateinit var prefs: android.content.SharedPreferences

    fun configure(context: Context) {
        if (Purchases.isConfigured) return
        prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        // Not in the screenshot tests (Robolectric), where the SDK refuses to start.
        if (android.os.Build.FINGERPRINT == "robolectric") return
        // RevenueCat only records purchases: if it can't start, the app goes on without it.
        runCatching {
            Purchases.logLevel = LogLevel.WARN
            Purchases.configure(
                PurchasesConfiguration.Builder(context.applicationContext, API_KEY)
                    .purchasesAreCompletedBy(PurchasesAreCompletedBy.MY_APP)
                    .build()
            )
        }
    }

    /** After a purchase or a restore: RevenueCat reads the Play purchases and records the new ones. */
    fun sync() {
        if (!Purchases.isConfigured) return
        runCatching { Purchases.sharedInstance.syncPurchases() }
    }

    /** Subscriptions bought before RevenueCat was in the app: sent once per install. */
    fun syncExistingPurchasesOnce() {
        if (!Purchases.isConfigured || !::prefs.isInitialized || prefs.getBoolean(SYNCED, false)) return
        sync()
        prefs.edit().putBoolean(SYNCED, true).apply()
    }
}
