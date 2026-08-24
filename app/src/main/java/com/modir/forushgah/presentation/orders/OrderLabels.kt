package com.modir.forushgah.presentation.orders

import com.modir.forushgah.domain.model.OrderStatus
import com.modir.forushgah.domain.model.ReturnReason
import com.modir.forushgah.domain.model.ReturnStatus
import com.modir.forushgah.domain.model.ShippingPaymentType

/** Spec §2: Persian labels for order statuses. */
fun OrderStatus.persianLabel(): String = when (this) {
    OrderStatus.NEW -> "جدید"
    OrderStatus.CONFIRMED -> "تأیید شده"
    OrderStatus.PREPARING -> "در حال آماده‌سازی"
    OrderStatus.SHIPPED -> "ارسال شده"
    OrderStatus.DELIVERED -> "تحویل شده"
    OrderStatus.RETURNED -> "مرجوع شده"
    OrderStatus.CANCELLED -> "لغو شده"
}

/** Spec §22: Persian labels for return statuses. */
fun ReturnStatus.persianLabel(): String = when (this) {
    ReturnStatus.REQUESTED -> "درخواست شده"
    ReturnStatus.APPROVED -> "تأیید شده"
    ReturnStatus.RECEIVED -> "دریافت شده"
    ReturnStatus.REFUNDED -> "مبلغ برگشت داده شده"
    ReturnStatus.REJECTED -> "رد شده"
}

fun ReturnReason.persianLabel(): String = when (this) {
    ReturnReason.CUSTOMER_REFUSED -> "رد مشتری هنگام تحویل"
    ReturnReason.DEFECTIVE -> "کالای معیوب"
    ReturnReason.WRONG_ITEM -> "ارسال کالای اشتباه"
    ReturnReason.OTHER -> "سایر"
}

/** Spec §11: Persian labels for shipping payment types. */
fun ShippingPaymentType.persianLabel(): String = when (this) {
    ShippingPaymentType.SELLER_PAID -> "پرداخت توسط فروشنده"
    ShippingPaymentType.CUSTOMER_PREPAID -> "پرداخت توسط مشتری"
    ShippingPaymentType.COD -> "پس‌کرایه"
}
