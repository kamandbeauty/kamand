package ir.factoryar.core.billing

import android.content.Context
import androidx.activity.result.ActivityResultRegistry
import dagger.hilt.android.qualifiers.ApplicationContext
import ir.cafebazaar.poolakey.Payment
import ir.cafebazaar.poolakey.config.PaymentConfiguration
import ir.cafebazaar.poolakey.config.SecurityCheck
import ir.cafebazaar.poolakey.request.PurchaseRequest
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

/**
 * مدیریت پرداخت درون‌برنامه‌ای کافه‌بازار (Poolakey) برای «اشتراک طلایی».
 *
 * پیش‌نیاز راه‌اندازی:
 * ۱. ثبت اپ در پنل توسعه‌دهندگان بازار و ساخت محصول اشتراکی (SKU)
 * ۲. قرار دادن کلید عمومی RSA بازار در [RSA_PUBLIC_KEY]
 * ۳. تنظیم SKU واقعی در [Sku.YEARLY] / [Sku.MONTHLY]
 *
 * نکته: اگر Poolakey روی میرور داخلی موجود نبود، نسخهٔ فعلی را از
 * mavenCentral یا گیت‌هاب cafebazaar/Poolakey دریافت کنید.
 */
@Singleton
class BillingManager @Inject constructor(
    @ApplicationContext private val context: Context,
    private val premiumStore: ir.factoryar.core.domain.repository.PremiumRepository,
) {
    private val scope = kotlinx.coroutines.CoroutineScope(
        kotlinx.coroutines.SupervisorJob() + kotlinx.coroutines.Dispatchers.IO,
    )

    object Sku {
        const val MONTHLY = "factoryar_gold_monthly"
        const val YEARLY = "factoryar_gold_yearly"
    }

    /** TODO: کلید عمومی RSA از پنل توسعه‌دهندگان بازار (بخش پرداخت درون‌برنامه‌ای) */
    private const val RSA_PUBLIC_KEY = "MIHNMA0GCSqGSIb3DQEBAQUAA4G7ADCBtwKBrwDv..."

    sealed interface BillingState {
        data object NotConnected : BillingState
        data object Connecting : BillingState
        data object Connected : BillingState
        data class Error(val message: String) : BillingState
    }

    private val _state = MutableStateFlow<BillingState>(BillingState.NotConnected)
    val state: StateFlow<BillingState> = _state

    private val _isPremium = MutableStateFlow(false)
    val isPremiumPremiumFlow: StateFlow<Boolean> = _isPremium

    private var payment: Payment? = null

    /** اتصال به سرویس پرداخت بازار — یک‌بار در شروع اپ صدا زده شود */
    fun connect(onPremiumChecked: (Boolean) -> Unit = {}) {
        if (payment != null) return
        _state.value = BillingState.Connecting
        val config = PaymentConfiguration(
            localSecurityCheck = SecurityCheck.Enable(rsaPublicKey = RSA_PUBLIC_KEY),
        )
        payment = Payment(context = context, config = config)
        payment?.connect {
            connectionSucceed {
                _state.value = BillingState.Connected
                refreshPurchases(onPremiumChecked)
            }
            connectionFailed {
                _state.value = BillingState.Error("اتصال به کافه‌بازار برقرار نشد")
            }
            disconnected {
                _state.value = BillingState.NotConnected
            }
        }
    }

    /** خواندن خریدهای فعلی کاربر (بازیابی اشتراک) */
    fun refreshPurchases(onResult: (Boolean) -> Unit = {}) {
        payment?.getSubscribedProducts {
            querySucceed { purchases ->
                val active = purchases.any { it.productId == Sku.MONTHLY || it.productId == Sku.YEARLY }
                _isPremium.value = active
                scope.launch { premiumStore.setPremium(active) }
                onResult(active)
            }
            queryFailed {
                onResult(_isPremium.value)
            }
        } ?: onResult(false)
    }

    /** شروع جریان خرید اشتراک — registry از ComponentActivity می‌آید */
    fun purchasePremium(
        registry: ActivityResultRegistry,
        sku: String = Sku.YEARLY,
        onSuccess: () -> Unit = {},
        onCanceled: () -> Unit = {},
        onError: (String) -> Unit = {},
    ) {
        val p = payment ?: return onError("سرویس پرداخت متصل نیست. ابتدا کافه‌بازار را نصب/به‌روزرسانی کنید.")
        p.subscribeActivity(registry, PurchaseRequest(productId = sku, payload = "factoryar_gold")) {
            purchaseSucceed {
                _isPremium.value = true
                scope.launch { premiumStore.setPremium(true) }
                onSuccess()
            }
            purchaseCanceled { onCanceled() }
            purchaseFailed { throwable ->
                onError(throwable.message ?: "خرید ناموفق بود")
            }
            failedToBeginFlow { throwable ->
                onError(throwable.message ?: "شروع فرایند خرید ممکن نشد")
            }
        }
    }

    fun disconnect() {
        payment?.disconnect()
        payment = null
        _state.value = BillingState.NotConnected
    }
}
