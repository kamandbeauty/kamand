package ir.factoryar.core.pdf

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import ir.factoryar.core.common.jalali.JalaliConverter
import ir.factoryar.core.common.util.CurrencyUnit
import ir.factoryar.core.common.util.PersianFormatter.formatMoney
import ir.factoryar.core.common.util.PersianFormatter.formatQuantity
import ir.factoryar.core.common.util.PersianFormatter.toPersianDigits
import ir.factoryar.core.domain.model.BusinessProfile
import ir.factoryar.core.domain.model.InvoiceType
import ir.factoryar.core.domain.model.InvoiceWithDetails
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream

/**
 * تولید PDF فاکتور (A4) با قالب فارسی، لوگو، امضا و واترمارک اختیاری.
 * از PDFDocument خود اندروید استفاده می‌کند — بدون وابستگی اضافه.
 */
class InvoicePdfGenerator(private val context: Context) {

    companion object {
        private const val PAGE_W = 595
        private const val PAGE_H = 842
        private const val MARGIN = 36f
        private const val ROW_H = 26f
    }

    private val textRight = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.RIGHT; color = Color.BLACK }
    private val textCenter = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER; color = Color.BLACK }
    private val textLeft = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.LEFT; color = Color.BLACK }
    private val line = Paint().apply { color = Color.LTGRAY; strokeWidth = 1f }

    suspend fun generate(
        details: InvoiceWithDetails,
        profile: BusinessProfile,
        currencyUnit: CurrencyUnit,
        showWatermark: Boolean,
    ): File = withContext(Dispatchers.IO) {
        val doc = PdfDocument()
        var pageNum = 1
        var page = doc.startPage(PdfDocument.PageInfo.Builder(PAGE_W, PAGE_H, pageNum).create())
        var canvas = page.canvas
        var y = drawHeader(canvas, details, profile, pageNum)

        // جدول اقلام
        y = drawTableHeader(canvas, y)
        val bottomLimit = PAGE_H - 170f
        details.items.forEachIndexed { index, item ->
            if (y > bottomLimit) {
                // صفحه جدید
                doc.finishPage(page)
                pageNum++
                page = doc.startPage(PdfDocument.PageInfo.Builder(PAGE_W, PAGE_H, pageNum).create())
                canvas = page.canvas
                y = drawTableHeader(canvas, MARGIN + 20f)
            }
            y = drawItemRow(canvas, y, index, item, currencyUnit)
        }
        y += 14f
        y = drawTotals(canvas, y, details, currencyUnit)
        drawFooter(canvas, details, profile, y, currencyUnit, showWatermark)
        doc.finishPage(page)

        val dir = File(context.getExternalFilesDir(null) ?: context.filesDir, "pdfs").apply { mkdirs() }
        val file = File(dir, "invoice_${details.invoice.number.ifBlank { details.invoice.id.toString() }}.pdf")
        FileOutputStream(file).use { doc.writeTo(it) }
        doc.close()
        file
    }

    private fun drawHeader(canvas: Canvas, details: InvoiceWithDetails, profile: BusinessProfile, pageNum: Int): Float {
        var y = MARGIN
        // لوگو
        var textStartX = MARGIN
        profile.logoPath?.takeIf { it.isNotBlank() }?.let { path ->
            runCatching {
                BitmapFactory.decodeFile(path)?.let { logo ->
                    val scaled = Bitmap.createScaledBitmap(logo, 56, 56, true)
                    canvas.drawBitmap(scaled, PAGE_W - MARGIN - 56, y, null)
                }
            }
        }
        // نام کسب‌وکار
        textLeft.apply { textSize = 16f; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD) }
        canvas.drawText(profile.name.ifBlank { "کسب‌وکار من" }, textStartX, y + 20f, textLeft)
        textLeft.apply { textSize = 10f; typeface = Typeface.DEFAULT; color = Color.DKGRAY }
        if (profile.phone.isNotBlank()) {
            canvas.drawText(profile.phone.toPersianDigits(), textStartX, y + 36f, textLeft)
        }
        if (profile.address.isNotBlank()) {
            canvas.drawText(profile.address, textStartX, y + 50f, textLeft)
        }

        y += 72f
        // نوار عنوان
        val titlePaint = Paint().apply { color = 0xFF1E5AA8.toInt() }
        canvas.drawRoundRect(RectF(MARGIN, y, PAGE_W - MARGIN, y + 34f), 8f, 8f, titlePaint)
        val title = when (details.invoice.type) {
            InvoiceType.PROFORMA -> "پیش‌فاکتور"
            InvoiceType.SALE -> "فاکتور فروش"
            InvoiceType.PURCHASE -> "فاکتور خرید"
        }
        textCenter.apply { textSize = 15f; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); color = Color.WHITE }
        canvas.drawText(title, PAGE_W / 2f, y + 22f, textCenter)

        y += 46f
        // شماره + تاریخ‌ها
        textRight.apply { textSize = 11f; typeface = Typeface.DEFAULT; color = Color.BLACK }
        textLeft.apply { textSize = 11f }
        canvas.drawText("شماره: ${details.invoice.number.toPersianDigits()}", PAGE_W - MARGIN, y, textRight)
        val issue = JalaliConverter.fromEpochMillis(details.invoice.issueDate).format().toPersianDigits()
        canvas.drawText("تاریخ صدور: $issue", PAGE_W / 2f + 10f, y, textRight)
        details.invoice.dueDate?.let {
            val due = JalaliConverter.fromEpochMillis(it).format().toPersianDigits()
            canvas.drawText("سررسید: $due", MARGIN, y, textLeft)
        }

        y += 18f
        // مشتری
        details.customer?.let { c ->
            canvas.drawText("مشتری: ${c.name}", PAGE_W - MARGIN, y, textRight)
            val phone = if (c.phone.isNotBlank()) "تماس: ${c.phone.toPersianDigits()}" else ""
            canvas.drawText(phone, MARGIN, y, textLeft)
            y += 16f
        }
        if (pageNum > 1) y += 6f
        canvas.drawLine(MARGIN, y, PAGE_W - MARGIN, y, line)
        return y + 6f
    }

    // ستون‌ها (پهنا، از راست): ردیف(30) شرح(*) تعداد(44) قیمت واحد(76) تخفیف(48) مالیات(48) جمع(84)
    private val colRow = 30f
    private val colQty = 44f
    private val colPrice = 76f
    private val colDisc = 48f
    private val colTax = 48f
    private val colTotal = 84f
    private val tableW get() = PAGE_W - 2 * MARGIN
    private val colTitle get() = tableW - (colRow + colQty + colPrice + colDisc + colTax + colTotal)

    private fun drawTableHeader(canvas: Canvas, yStart: Float): Float {
        val bg = Paint().apply { color = 0xFFF1F3F5.toInt() }
        canvas.drawRect(MARGIN, yStart, PAGE_W - MARGIN, yStart + ROW_H, bg)
        val right = PAGE_W - MARGIN
        textCenter.apply { textSize = 10.5f; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD) }
        var x = right
        val ty = yStart + 17f
        fun cell(label: String, w: Float) {
            canvas.drawText(label, x - w / 2f, ty, textCenter); x -= w
        }
        cell("ردیف", colRow); cell("شرح کالا / خدمات", colTitle); cell("تعداد", colQty)
        cell("قیمت واحد", colPrice); cell("تخفیف٪", colDisc); cell("مالیات٪", colTax); cell("مبلغ کل", colTotal)
        canvas.drawLine(MARGIN, yStart + ROW_H, PAGE_W - MARGIN, yStart + ROW_H, line)
        return yStart + ROW_H
    }

    private fun drawItemRow(canvas: Canvas, y: Float, index: Int, item: ir.factoryar.core.domain.model.InvoiceItem, unit: CurrencyUnit): Float {
        val right = PAGE_W - MARGIN
        val ty = y + 17f
        textCenter.apply { textSize = 10f; typeface = Typeface.DEFAULT }
        var x = right
        canvas.drawText((index + 1).toString().toPersianDigits(), x - colRow / 2f, ty, textCenter); x -= colRow
        // شرح (راست‌چین با برش متن)
        textRight.apply { textSize = 10f }
        val title = ellipsize(item.title, colTitle - 10f, textRight)
        canvas.drawText(title, x - 6f, ty, textRight); x -= colTitle
        canvas.drawText(formatQuantity(item.quantity), x - colQty / 2f, ty, textCenter); x -= colQty
        canvas.drawText(formatMoney(item.unitPrice), x - colPrice / 2f, ty, textCenter); x -= colPrice
        canvas.drawText(if (item.discountPercent > 0) formatQuantity(item.discountPercent) else "—", x - colDisc / 2f, ty, textCenter); x -= colDisc
        canvas.drawText(if (item.taxPercent > 0) formatQuantity(item.taxPercent) else "—", x - colTax / 2f, ty, textCenter); x -= colTax
        textCenter.apply { typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD) }
        canvas.drawText(formatMoney(item.lineTotal), x - colTotal / 2f, ty, textCenter)
        textCenter.typeface = Typeface.DEFAULT
        canvas.drawLine(MARGIN, y + ROW_H, PAGE_W - MARGIN, y + ROW_H, line)
        return y + ROW_H
    }

    private fun ellipsize(text: String, maxW: Float, paint: Paint): String {
        if (paint.measureText(text) <= maxW) return text
        var t = text
        while (t.isNotEmpty() && paint.measureText("$t…") > maxW) t = t.dropLast(1)
        return "$t…"
    }

    private fun drawTotals(canvas: Canvas, yStart: Float, details: InvoiceWithDetails, unit: CurrencyUnit): Float {
        var y = yStart
        val labelPaint = textRight.apply { textSize = 11f }
        val valuePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.LEFT; textSize = 11f }
        fun row(label: String, amount: Long, bold: Boolean = false) {
            labelPaint.typeface = if (bold) Typeface.create(Typeface.DEFAULT, Typeface.BOLD) else Typeface.DEFAULT
            valuePaint.typeface = labelPaint.typeface
            canvas.drawText(label, PAGE_W - MARGIN, y + 14f, labelPaint)
            canvas.drawText("${formatMoney(amount)} ${unit.faName}", PAGE_W / 2f, y + 14f, valuePaint)
            y += 20f
        }
        row("جمع اقلام:", details.invoice.subtotal)
        row("تخفیف:", details.invoice.discountTotal)
        row("مالیات بر ارزش افزوده:", details.invoice.taxTotal)
        canvas.drawLine(PAGE_W / 2f, y, PAGE_W - MARGIN, y, line)
        y += 8f
        row("مبلغ قابل پرداخت:", details.invoice.grandTotal, bold = true)
        if (details.invoice.paidAmount > 0) {
            row("پرداخت‌شده:", details.invoice.paidAmount)
            row("مانده:", details.invoice.remainingAmount, bold = true)
        }
        return y + 10f
    }

    private fun drawFooter(
        canvas: Canvas,
        details: InvoiceWithDetails,
        profile: BusinessProfile,
        yStart: Float,
        unit: CurrencyUnit,
        showWatermark: Boolean,
    ) {
        var y = (yStart + 6f).coerceAtMost(PAGE_H - 120f)
        if (details.invoice.note.isNotBlank()) {
            textRight.apply { textSize = 10f; typeface = Typeface.DEFAULT; color = Color.DKGRAY }
            canvas.drawText("یادداشت: ${details.invoice.note}", PAGE_W - MARGIN, y, textRight)
            y += 16f
        }
        val terms = details.invoice.terms.ifBlank { profile.defaultTerms }
        if (terms.isNotBlank()) {
            textRight.apply { textSize = 9.5f; color = Color.GRAY }
            canvas.drawText("شرایط: $terms", PAGE_W - MARGIN, y, textRight)
            y += 16f
        }

        // امضا
        textCenter.apply { textSize = 10f; color = Color.DKGRAY }
        canvas.drawText("مهر و امضای فروشنده", MARGIN + 60f, PAGE_H - 100f, textCenter)
        canvas.drawText("مهر و امضای خریدار", PAGE_W - MARGIN - 60f, PAGE_H - 100f, textCenter)
        details.invoice.signaturePath?.takeIf { it.isNotBlank() }?.let { path ->
            runCatching {
                BitmapFactory.decodeFile(path)?.let { sig ->
                    val scaled = Bitmap.createScaledBitmap(sig, 110, 44, true)
                    canvas.drawBitmap(scaled, MARGIN + 5f, PAGE_H - 94f, null)
                }
            }
        }

        // واترمارک نسخه رایگان
        if (showWatermark) {
            textCenter.apply { textSize = 8.5f; color = Color.parseColor("#9AA0A6") }
            canvas.drawText("صادر شده با اپلیکیشن فاکتوریار — نسخه رایگان", PAGE_W / 2f, PAGE_H - 20f, textCenter)
        }
    }
}
