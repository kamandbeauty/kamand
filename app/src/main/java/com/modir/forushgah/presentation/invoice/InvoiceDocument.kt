package com.modir.forushgah.presentation.invoice

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CreditCard
import androidx.compose.material3.Divider
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.modir.forushgah.core.common.InvoiceFormatting
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.core.common.isNegative
import com.modir.forushgah.core.common.isPositive
import com.modir.forushgah.core.common.PersianNumberFormatter
import com.modir.forushgah.core.date.JalaliDateFormatter
import com.modir.forushgah.data.repository.OrderDetail
import com.modir.forushgah.domain.model.StoreProfile

// Rubi invoice document palette (reference: invoice_preview_screen.dart).
val DocOrange = Color(0xFFF97316)
val DocSlate400 = Color(0xFF94A3B8)
val DocSlate500 = Color(0xFF64748B)
val DocSlate700 = Color(0xFF334155)
val DocSlate800 = Color(0xFF1E293B)
val DocCardGray = Color(0xFFF1F5F9)
val DocBorder = Color(0xFFE2E8F0)
val DocSuccess = Color(0xFF059669)
val DocWarning = Color(0xFFD97706)
val DocDanger = Color(0xFFE11D48)
val DocInfo = Color(0xFF0284C7)

/**
 * The Rubi invoice paper — header (shop identity + number/date box), buyer
 * row, item table (عنوان/مقدار/واحد/فی/جمع), total rows, notes, bank card box
 * and the «مهر و امضا» area. Rendered identically on screen and in the
 * image/PDF-like output (spec §10/§11). Pure display: all numbers come from
 * the Phase 3 domain model.
 */
@Composable
fun InvoiceDocument(
    detail: OrderDetail,
    store: StoreProfile?,
    modifier: Modifier = Modifier,
) {
    val order = detail.order
    val typeTitle = if (order.kind == com.modir.forushgah.domain.model.OrderKind.PURCHASE) "فاکتور خرید" else "فاکتور فروش"
    val isCash = detail.totalPaid >= detail.total && detail.payments.any { it.method.contains("نقدی") }
    val partyName = (if (order.kind == com.modir.forushgah.domain.model.OrderKind.PURCHASE) detail.supplierName else detail.customerName).orEmpty()

    Column(modifier = modifier.fillMaxWidth().padding(16.dp)) {
        // ---- Header: logo box + shop identity + number/date box ----
        Row(verticalAlignment = Alignment.Top) {
            Box(
                modifier = Modifier
                    .size(64.dp)
                    .background(Color.Transparent, RoundedCornerShape(14.dp)),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    "ف",
                    color = DocOrange,
                    fontWeight = FontWeight.W900,
                    fontSize = 22.sp,
                )
            }
            Spacer(modifier = Modifier.width(10.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    (store?.storeName ?: "").ifEmpty { "فروشگاه روبی" },
                    fontWeight = FontWeight.W900,
                    fontSize = 16.sp,
                    color = Color(0xFF0F172A),
                )
                (store?.phone).orEmpty().takeIf { it.isNotEmpty() }?.let {
                    Text(it, fontSize = 11.sp, color = DocSlate500, textDirection = TextDirection.Ltr, textAlign = TextAlign.End)
                }
                (store?.address).orEmpty().takeIf { it.isNotEmpty() }?.let {
                    Text(it, fontSize = 11.sp, color = DocSlate500, lineHeight = (11.sp * 1.4f))
                }
            }
            Spacer(modifier = Modifier.width(10.dp))
            Surface(
                shape = RoundedCornerShape(12.dp),
                color = DocCardGray,
                border = BorderStroke(1.dp, DocBorder),
            ) {
                Column(
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 8.dp),
                    horizontalAlignment = Alignment.End,
                ) {
                    Text(typeTitle, color = DocOrange, fontWeight = FontWeight.W900, fontSize = 12.sp)
                    Text("شماره: ${PersianNumberFormatter.toPersianDigits(order.orderNumber)}", fontSize = 10.sp, fontWeight = FontWeight.W700)
                    Text("تاریخ: ${JalaliDateFormatter.formatJalali(order.orderDate)}", fontSize = 10.sp, fontWeight = FontWeight.W700)
                }
            }
        }
        Spacer(modifier = Modifier.height(14.dp))

        // ---- Buyer row ----
        Surface(shape = RoundedCornerShape(12.dp), color = DocCardGray) {
            Row(
                modifier = Modifier.padding(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "${if (order.kind == com.modir.forushgah.domain.model.OrderKind.PURCHASE) "تأمین‌کننده" else "خریدار"}: " +
                        partyName.ifEmpty { "مشتری عمومی" },
                    fontWeight = FontWeight.W800,
                    fontSize = 12.sp,
                    modifier = Modifier.weight(1f),
                )
                (detail.customerMobile).orEmpty().takeIf { it.isNotEmpty() }?.let {
                    Text(it, fontSize = 11.sp, color = DocSlate500, textDirection = TextDirection.Ltr)
                }
            }
        }
        Spacer(modifier = Modifier.height(12.dp))

        // ---- Items table ----
        Surface(shape = RoundedCornerShape(12.dp), border = BorderStroke(1.dp, DocBorder)) {
            Column {
                // header
                Row(
                    modifier = Modifier
                        .background(Color(0xFFF8FAFC), RoundedCornerShape(topStart = 12.dp, topEnd = 12.dp))
                        .padding(vertical = 8.dp, horizontal = 6.dp),
                ) {
                    Text("عنوان", textAlign = TextAlign.Center, fontSize = 10.sp, fontWeight = FontWeight.W800, modifier = Modifier.weight(3f))
                    Text("مقدار", textAlign = TextAlign.Center, fontSize = 10.sp, fontWeight = FontWeight.W800, modifier = Modifier.weight(1f))
                    Text("واحد", textAlign = TextAlign.Center, fontSize = 10.sp, fontWeight = FontWeight.W800, modifier = Modifier.weight(1f))
                    Text("فی", textAlign = TextAlign.Center, fontSize = 10.sp, fontWeight = FontWeight.W800, modifier = Modifier.weight(2f))
                    Text("جمع", textAlign = TextAlign.Center, fontSize = 10.sp, fontWeight = FontWeight.W800, modifier = Modifier.weight(2f))
                }
                detail.items.forEachIndexed { index, row ->
                    val item = row.item
                    val isLast = index == detail.items.lastIndex
                    if (!isLast) {
                        Divider(thickness = 1.dp, color = Color(0xFFEEEEEE))
                    }
                    Row(
                        modifier = Modifier.padding(vertical = 8.dp, horizontal = 6.dp),
                    ) {
                        Text(
                            "${PersianNumberFormatter.toPersianDigits((index + 1).toString())}. " +
                                (row.productName.ifEmpty { "—" }),
                            fontSize = 11.sp,
                            fontWeight = FontWeight.W700,
                            textAlign = TextAlign.End,
                            modifier = Modifier.weight(3f),
                        )
                        Text(
                            PersianNumberFormatter.toPersianDigits(item.quantity.toString()),
                            textAlign = TextAlign.Center,
                            fontSize = 11.sp,
                            modifier = Modifier.weight(1f),
                        )
                        Text(
                            item.unit,
                            textAlign = TextAlign.Center,
                            fontSize = 10.sp,
                            color = DocSlate500,
                            modifier = Modifier.weight(1f),
                        )
                        Text(
                            InvoiceFormatting.formatCurrencyShort(item.unitSellingPrice),
                            textAlign = TextAlign.Center,
                            fontSize = 10.sp,
                            modifier = Modifier.weight(2f),
                        )
                        Text(
                            InvoiceFormatting.formatCurrencyShort(Money(item.unitSellingPrice.amountInToman * item.quantity - item.discount.amountInToman)),
                            textAlign = TextAlign.Center,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.W800,
                            modifier = Modifier.weight(2f),
                        )
                    }
                }
            }
        }
        Spacer(modifier = Modifier.height(12.dp))

        // ---- Totals (Rubi rows) ----
        DocTotalRow("جمع اقلام", subtotalOf(detail))
        if (order.discount.isPositive) {
            DocTotalRow("تخفیف", -order.discount, color = DocSuccess)
        }
        if (order.shippingChargedToCustomer.isPositive) {
            DocTotalRow("هزینه ارسال", order.shippingChargedToCustomer)
        }
        Divider(modifier = Modifier.padding(vertical = 5.dp), color = DocBorder)
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("مبلغ قابل پرداخت", fontWeight = FontWeight.W900, fontSize = 13.sp, modifier = Modifier.weight(1f))
            Text(
                InvoiceFormatting.formatCurrency(detail.total),
                fontWeight = FontWeight.W900,
                fontSize = 16.sp,
                color = DocOrange,
            )
        }
        if (detail.totalPaid.isPositive && !isCash) {
            Spacer(modifier = Modifier.height(6.dp))
            DocTotalRow("پرداخت‌شده / بیعانه", detail.totalPaid, color = DocSuccess)
        }
        if (detail.remaining.isPositive) {
            Spacer(modifier = Modifier.height(4.dp))
            DocTotalRow("باقی‌مانده", detail.remaining, color = DocDanger)
        }
        (order.notes).orEmpty().takeIf { it.isNotEmpty() }?.let {
            Spacer(modifier = Modifier.height(12.dp))
            Text("توضیحات: $it", fontSize = 11.sp, color = DocSlate500, lineHeight = (11.sp * 1.4f))
        }

        // ---- Bank card box (Rubi «شماره کارت جهت واریز») ----
        (store?.bankCardNumber).orEmpty().takeIf { it.isNotEmpty() }?.let { card ->
            Spacer(modifier = Modifier.height(12.dp))
            Surface(
                shape = RoundedCornerShape(12.dp),
                color = Color(0xFFF0F9FF),
                border = BorderStroke(1.dp, Color(0xFFBAE6FD)),
            ) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Row(verticalAlignment = Alignment.Top) {
                        Box(modifier = Modifier.weight(1f)) {
                            Box(
                                modifier = Modifier
                                    .align(Alignment.TopEnd)
                                    .background(Color.Black, RoundedCornerShape(6.dp))
                                    .padding(horizontal = 6.dp, vertical = 3.dp),
                            ) {
                                Text(
                                    "اپلیکیشن فاکتور ساز روبی",
                                    fontSize = 9.sp,
                                    color = Color.White,
                                    fontWeight = FontWeight.W700,
                                )
                            }
                        }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                Icons.Outlined.CreditCard,
                                contentDescription = null,
                                tint = DocInfo,
                                modifier = Modifier.size(20.dp),
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                "شماره کارت جهت واریز",
                                fontSize = 10.sp,
                                color = DocInfo,
                                fontWeight = FontWeight.W700,
                            )
                        }
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        InvoiceFormatting.formatCardGrouped(card),
                        fontWeight = FontWeight.W900,
                        fontSize = 16.sp,
                        letterSpacing = 1.1.sp,
                        color = Color(0xFF0F172A),
                        textDirection = TextDirection.Ltr,
                        textAlign = TextAlign.End,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    (store?.storeName).orEmpty().takeIf { it.isNotEmpty() }?.let {
                        Spacer(modifier = Modifier.height(6.dp))
                        Text(
                            "دارنده کارت: $it",
                            fontSize = 11.sp,
                            color = DocSlate700,
                            fontWeight = FontWeight.W700,
                        )
                    }
                }
            }
        }
        Spacer(modifier = Modifier.height(20.dp))

        // ---- Stamp / signature area (Rubi: bottom-left, «مهر و امضا») ----
        Row(modifier = Modifier.fillMaxWidth()) {
            Box(modifier = Modifier.weight(1f))
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Spacer(modifier = Modifier.height(56.dp))
                Spacer(modifier = Modifier.height(4.dp))
                Text("مهر و امضا", fontSize = 9.sp, color = DocSlate400)
            }
        }
    }
}

/** Rubi `_totalRow`: label left (end), amount right; negative shows a minus sign. */
@Composable
private fun DocTotalRow(label: String, amount: Money, color: Color = DocSlate700) {
    val negative = amount.isNegative
    Box(modifier = Modifier.padding(bottom = 4.dp)) {
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(label, fontSize = 11.sp, color = color, fontWeight = FontWeight.W600, modifier = Modifier.weight(1f))
            Text(
                (if (negative) "− " else "") + InvoiceFormatting.formatCurrency(amount.coerceAtLeastZero()),
                fontSize = 11.sp,
                color = color,
                fontWeight = FontWeight.W800,
            )
        }
    }
}

private fun subtotalOf(detail: OrderDetail): Money =
    Money.sum(detail.items.map { Money(it.item.unitSellingPrice.amountInToman * it.item.quantity - it.item.discount.amountInToman) })
