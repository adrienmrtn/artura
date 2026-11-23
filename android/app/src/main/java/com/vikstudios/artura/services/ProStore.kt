package com.vikstudios.artura.services

import android.app.Activity
import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.android.billingclient.api.acknowledgePurchase
import com.android.billingclient.api.queryProductDetails
import com.android.billingclient.api.queryPurchasesAsync
import com.vikstudios.artura.core.L
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.math.BigDecimal
import java.math.RoundingMode
import java.text.NumberFormat
import java.time.Period
import java.util.Currency

/**
 * Artura Pro subscription (Google Play Billing). Same offers as iOS:
 * - `artura_yearly`, `artura_monthly`: 3-day free trial;
 * - `artura_yearly_gift`: the yearly plan 40% cheaper, 7-day free trial (last-minute gift offer).
 * Each is a subscription in the Play Console with one base plan and a free-trial offer.
 */
class ProStore(private val context: Context) {
    /** A subscription as the screens see it (product + chosen offer). */
    data class Product(
        val id: String,
        val details: ProductDetails,
        val offerToken: String,
        /** "$29.99": price of the base plan. */
        val displayPrice: String,
        val priceMicros: Long,
        val currencyCode: String,
        /** Length of the free trial in days, if the offer has one. */
        val trialDays: Int?,
    ) {
        val price: BigDecimal get() = BigDecimal(priceMicros).divide(BigDecimal(1_000_000))

        /** Formats an amount in the product's currency. */
        fun format(amount: BigDecimal): String {
            val f = NumberFormat.getCurrencyInstance(com.vikstudios.artura.core.AppLanguage.locale)
            runCatching { f.currency = Currency.getInstance(currencyCode) }
            return f.format(amount)
        }
    }

    var products by mutableStateOf<List<Product>>(emptyList())
        private set
    var isPro by mutableStateOf(false)
        private set
    var isPurchasing by mutableStateOf(false)
        private set
    var lastError by mutableStateOf<String?>(null)

    val yearly get() = products.firstOrNull { it.id == YEARLY }
    val monthly get() = products.firstOrNull { it.id == MONTHLY }
    val yearlyExtended get() = products.firstOrNull { it.id == YEARLY_GIFT }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var pendingPurchase: CompletableDeferred<Boolean>? = null
    private var pendingProduct: Product? = null

    private val client: BillingClient = BillingClient.newBuilder(context)
        .setListener { result, purchases -> onPurchases(result, purchases) }
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .build()

    init { connect() }

    private fun connect() {
        client.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    scope.launch { loadProducts(); refreshEntitlements() }
                }
            }
            override fun onBillingServiceDisconnected() {}
        })
    }

    suspend fun loadProducts() {
        if (!client.isReady) return
        val params = QueryProductDetailsParams.newBuilder().setProductList(ALL_IDS.map {
            QueryProductDetailsParams.Product.newBuilder().setProductId(it).setProductType(BillingClient.ProductType.SUBS).build()
        }).build()
        val result = client.queryProductDetails(params)
        if (result.billingResult.responseCode != BillingClient.BillingResponseCode.OK) {
            lastError = L("Couldn't load the plans.")
            return
        }
        products = result.productDetailsList.orEmpty().mapNotNull { product(it) }
    }

    /** Picks the offer with a free trial when there is one, else the base plan. */
    private fun product(details: ProductDetails): Product? {
        val offers = details.subscriptionOfferDetails ?: return null
        val withTrial = offers.firstOrNull { o -> o.pricingPhases.pricingPhaseList.any { it.priceAmountMicros == 0L } }
        val offer = withTrial ?: offers.firstOrNull() ?: return null
        val phases = offer.pricingPhases.pricingPhaseList
        val base = phases.last()
        val trial = phases.firstOrNull { it.priceAmountMicros == 0L }?.let { phase ->
            runCatching {
                val p = Period.parse(phase.billingPeriod)
                (p.years * 365 + p.months * 30 + p.days) * maxOf(1, phase.billingCycleCount)
            }.getOrNull()
        }
        return Product(details.productId, details, offer.offerToken, base.formattedPrice, base.priceAmountMicros, base.priceCurrencyCode, trial)
    }

    suspend fun refreshEntitlements() {
        if (!client.isReady) return
        val result = client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.SUBS).build())
        var pro = false
        for (purchase in result.purchasesList) {
            if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED && purchase.products.any { it in ALL_IDS }) {
                pro = true
                acknowledge(purchase)
            }
        }
        isPro = pro
        Analytics.isPro = pro
    }

    private suspend fun acknowledge(purchase: Purchase) {
        if (purchase.isAcknowledged) return
        client.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder().setPurchaseToken(purchase.purchaseToken).build())
    }

    /** Starts the purchase. Returns true if the subscription is active at the end. */
    suspend fun purchase(activity: Activity, product: Product): Boolean {
        Analytics.track("purchase_started", mapOf("product" to product.id, "price" to product.displayPrice))
        isPurchasing = true
        lastError = null
        try {
            val deferred = CompletableDeferred<Boolean>()
            pendingPurchase = deferred
            pendingProduct = product
            val params = BillingFlowParams.newBuilder().setProductDetailsParamsList(listOf(
                BillingFlowParams.ProductDetailsParams.newBuilder()
                    .setProductDetails(product.details).setOfferToken(product.offerToken).build()
            )).build()
            val launch = client.launchBillingFlow(activity, params)
            if (launch.responseCode != BillingClient.BillingResponseCode.OK) {
                lastError = L("The purchase failed. Try again in a moment.")
                return false
            }
            return deferred.await()
        } finally {
            isPurchasing = false
            pendingPurchase = null
            pendingProduct = null
        }
    }

    private fun onPurchases(result: BillingResult, purchases: List<Purchase>?) {
        val product = pendingProduct
        scope.launch {
            when (result.responseCode) {
                BillingClient.BillingResponseCode.OK -> {
                    val bought = purchases.orEmpty().firstOrNull { it.purchaseState == Purchase.PurchaseState.PURCHASED }
                    if (bought != null) {
                        acknowledge(bought)
                        refreshEntitlements()
                        Analytics.track("purchase_succeeded", mapOf("product" to (product?.id ?: bought.products.firstOrNull()), "price" to product?.displayPrice))
                        pendingPurchase?.complete(true)
                    } else {
                        Analytics.track("purchase_pending", mapOf("product" to product?.id))
                        pendingPurchase?.complete(false)
                    }
                }
                BillingClient.BillingResponseCode.USER_CANCELED -> {
                    Analytics.track("purchase_cancelled", mapOf("product" to product?.id))
                    pendingPurchase?.complete(false)
                }
                BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED -> {
                    refreshEntitlements()
                    pendingPurchase?.complete(isPro)
                }
                else -> {
                    lastError = L("The purchase failed. Try again in a moment.")
                    pendingPurchase?.complete(false)
                }
            }
        }
    }

    suspend fun restore() {
        if (!client.isReady) connect()
        refreshEntitlements()
    }

    companion object {
        const val YEARLY = "artura_yearly"
        const val MONTHLY = "artura_monthly"
        /** Gift offer: the yearly subscription 40% cheaper, with a 7-day trial instead of 3. */
        const val YEARLY_GIFT = "artura_yearly_gift"
        val ALL_IDS = listOf(YEARLY, MONTHLY, YEARLY_GIFT)
    }
}

/** What the free trial screens display: price and duration, read from the Play product. */
class TrialOffer private constructor(
    val product: ProStore.Product?,
    val trialDays: Int,
    /** "$29.99" */
    val yearlyPrice: String,
    /** "$2.50" */
    val monthlyPrice: String,
    /** "$0.00" */
    val zeroPrice: String,
    /** Yearly price as a number, to compute the discount of the gift offer. */
    val yearlyAmount: BigDecimal,
) {
    companion object {
        /** Null when the product is not loaded or has no free trial. */
        fun of(product: ProStore.Product?): TrialOffer? {
            val p = product ?: return null
            val days = p.trialDays ?: return null
            return TrialOffer(p, days, p.displayPrice, p.format(p.price.divide(BigDecimal(12), 2, RoundingMode.HALF_UP)),
                p.format(BigDecimal.ZERO), p.price)
        }

        /** Sample values, used while the Play product is not available. Nothing can be bought with it: the trial button just opens the app. */
        fun preview(days: Int, gift: Boolean = false) = TrialOffer(
            null, days,
            if (gift) "$17.99" else "$29.99",
            if (gift) "$1.50" else "$2.50",
            "$0.00",
            BigDecimal(if (gift) "17.99" else "29.99"),
        )
    }
}
