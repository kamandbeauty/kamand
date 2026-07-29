package ir.factoryar.core.printer

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import ir.factoryar.core.common.jalali.JalaliConverter
import ir.factoryar.core.common.util.CurrencyUnit
import ir.factoryar.core.common.util.PersianFormatter.formatMoney
import ir.factoryar.core.common.util.PersianFormatter.toPersianDigits
import ir.factoryar.core.domain.model.BusinessProfile
import ir.factoryar.core.domain.model.InvoiceItem
import ir.factoryar.core.domain.model.InvoiceWithDetails

data class PrintConfig(
    val paperSizeMm: Int = 80,
    val showLogo: Boolean = true,
    val showSignature: Boolean = true,
    val showTerms: Boolean = true,
)

/**
 * رندر رسید فاکتور به Bitmap سیاه‌وسفید برای چاپگرهای حرارتی ESC/POS.
 * متن فارسی به‌صورت تصویر چاپ می‌شود چون فونت داخلی پرینتر فارسی ندارد.
 */
class ReceiptRenderer {

    companion object {
        fun widthFor(mm: Int): Int = if (mm <= 58) 384 else 576
    }

    fun render(
        details: InvoiceWithDetails,
        profile: BusinessProfile,
        unit: CurrencyUnit,
        config: PrintConfig,
    ): Bitmap {
        val width = widthFor(config.paperSizeMm)
        val m = 14

        // دو مرحله: ابتدا اندازه‌گیری ارتفاع، سپس رندر واقعی
        val measure = MeasureCanvas(width, m, details, profile, unit, config)
        val height = measure.computeHeight()

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)

        val drawer = Drawer(canvas, width, m)
        var y = 8f

        // Logo
        if (config.showLogo) {
            profile.logoPath?.takeIf { it.isNotBlank() }?.let { path ->
                runCatching {
                    BitmapFactory.decodeFile(path)?.let { logo ->
                        val size = if (width <= 384) 64 else 88
                        val scaled = Bitmap.createScaledBitmap(logo, size, size, true)
                        canvas.drawBitmap(scaled, (width - size) / 2f, y, null)
                        y += size + 8f
                    }
                }
            }
        }

        y = drawer.center(profile.name.ifBlank { "کسب‌وکار من" }, y, 22f, bold = true)
        if (profile.phone.isNotBlank()) y = drawer.center(profile.phone.toPersianDigits(), y, 15f)
        if (profile.address.isNotBlank()) y = drawer.center(profile.address, y, 14f)
        y = drawer.divider(y + 6f)

        y = drawer.center(
            when (details.invoice.type) {
                ir.factoryar.core.domain.model.InvoiceType.PROFORMA -> "پیش‌فاکتور"
                ir.factoryar.core.domain.model.InvoiceType.SALE -> "فاکتور فروش"
                ir.factoryar.core.domain.model.InvoiceType.PURCHASE -> "فاکتور خرید"
            },
            y, 18f, bold = true,
        )
        y = drawer.center("شماره: ${details.invoice.number.toPersianDigits()}", y, 15f)
        y = drawer.center(JalaliConverter.fromEpochMillis(details.invoice.issueDate).format().toPersianDigits(), y, 15f)
        details.customer?.let { y = drawer.center("مشتری: ${it.name}", y, 15f) }
        y = drawer.divider(y + 4f)

        // آیتم‌ها
        details.items.forEachIndexed { i, item ->
            y = drawer.right("${i + 1}. ${item.title}", y, 15f)
            val line2 = "${ir.factoryar.core.common.util.PersianFormatter.formatQuantity(item.quantity)} × ${formatMoney(item.unitPrice)} = ${formatMoney(item.lineTotal)} ${unit.faName}"
            y = drawer.right(line2, y, 13.5f, color = Color.DKGRAY)
        }
        y = drawer.divider(y + 4f)

        y = drawer.totalRow("جمع اقلام:", "${formatMoney(details.invoice.subtotal)} ${unit.faName}", y)
        if (details.invoice.discountTotal > 0) y = drawer.totalRow("تخفیف:", "${formatMoney(details.invoice.discountTotal)} ${unit.faName}", y)
        if (details.invoice.taxTotal > 0) y = drawer.totalRow("مالیات:", "${formatMoney(details.invoice.taxTotal)} ${unit.faName}", y)
        drawer.bigDivider(y); y += 14f
        y = drawer.totalRow("قابل پرداخت:", "${formatMoney(details.invoice.grandTotal)} ${unit.faName}", y, big = true)
        if (details.invoice.paidAmount > 0) {
            y = drawer.totalRow("پرداخت‌شده:", "${formatMoney(details.invoice.paidAmount)} ${unit.faName}", y)
            y = drawer.totalRow("مانده:", "${formatMoney(details.invoice.remainingAmount)} ${unit.faName}", y)
        }
        y += 8f
        y = drawer.center(details.invoice.statusLabel, y, 15f, bold = true)

        if (config.showTerms) {
            val terms = details.invoice.terms.ifBlank { profile.defaultTerms }
            if (terms.isNotBlank()) y = drawer.centerWrapped(terms, y + 4f, 12.5f, Color.GRAY)
        }

        if (config.showSignature) {
            details.invoice.signaturePath?.takeIf { it.isNotBlank() }?.let { path ->
                runCatching {
                    BitmapFactory.decodeFile(path)?.let { sig ->
                        y = drawer.center("امضا:", y + 6f, 13f)
                        val w = width / 3
                        val h = w * sig.height / sig.width
                        canvas.drawBitmap(Bitmap.createScaledBitmap(sig, w, h, true), (width - w) / 2f, y, null)
                        y += h + 6f
                    }
                }
            }
        }

        y = drawer.divider(y + 6f)
        y = drawer.center("با تشکر از خرید شما", y, 14f)
        drawer.center("فاکتوریار", y, 11f, color = Color.LTGRAY)

        return bitmap
    }

    // ---------- ابزار رسم ----------
    private open inner class BaseDrawer(val width: Int, val margin: Int) {
        fun textHeight(size: Float) = size * 1.5f
    }

    private inner class Drawer(val canvas: Canvas, width: Int, margin: Int) {
        private fun paint(size: Float, bold: Boolean, color: Int, align: Paint.Align) =
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                textSize = size
                this.color = color
                textAlign = align
                typeface = if (bold) Typeface.create(Typeface.DEFAULT, Typeface.BOLD) else Typeface.DEFAULT
            }

        fun center(text: String, y: Float, size: Float, bold: Boolean = false, color: Int = Color.BLACK): Float {
            canvas.drawText(text, width / 2f, y + size, paint(size, bold, color, Paint.Align.CENTER))
            return y + size * 1.55f
        }

        fun right(text: String, y: Float, size: Float, bold: Boolean = false, color: Int = Color.BLACK): Float {
            canvas.drawText(text, width - margin.toFloat(), y + size, paint(size, bold, color, Paint.Align.RIGHT))
            return y + size * 1.55f
        }

        fun totalRow(label: String, value: String, y: Float, big: Boolean = false): Float {
            val size = if (big) 19f else 15f
            canvas.drawText(label, width - margin.toFloat(), y + size, paint(size, big, Color.BLACK, Paint.Align.RIGHT))
            canvas.drawText(value, margin.toFloat(), y + size, paint(size, big, Color.BLACK, Paint.Align.LEFT))
            return y + size * 1.6f
        }

        fun centerWrapped(text: String, y: Float, size: Float, color: Int = Color.BLACK): Float {
            val p = paint(size, false, color, Paint.Align.CENTER)
            val words = text.split(" ")
            var line = ""
            var yy = y
            for (w in words) {
                val candidate = if (line.isEmpty()) w else "$line $w"
                if (p.measureText(candidate) > width - 2 * margin) {
                    canvas.drawText(line, width / 2f, yy + size, p)
                    yy += size * 1.5f
                    line = w
                } else line = candidate
            }
            if (line.isNotEmpty()) {
                canvas.drawText(line, width / 2f, yy + size, p)
                yy += size * 1.5f
            }
            return yy
        }

        fun divider(y: Float): Float {
            val p = Paint().apply { color = Color.BLACK; strokeWidth = 2f }
            var x = margin.toFloat()
            while (x < width - margin) {
                canvas.drawLine(x, y, x + 10f, y, p)
                x += 18f
            }
            return y + 10f
        }

        fun bigDivider(y: Float) {
            val p = Paint().apply { color = Color.BLACK; strokeWidth = 3f }
            canvas.drawLine(margin.toFloat(), y, (width - margin).toFloat(), y, p)
        }
    }

    private inner class MeasureCanvas(
        width: Int,
        margin: Int,
        private val details: InvoiceWithDetails,
        private val profile: BusinessProfile,
        private val unit: CurrencyUnit,
        private val config: PrintConfig,
    ) : BaseDrawer(width, margin) {
        fun computeHeight(): Int {
            var h = 16f
            if (config.showLogo && !profile.logoPath.isNullOrBlank()) h += if (width <= 384) 72f else 96f
            h += textHeight(22f) + textHeight(15f) * 2 + 16f
            h += textHeight(18f) + textHeight(15f) * 3 + 14f
            details.items.forEach { h += textHeight(15f) + textHeight(13.5f) }
            h += 14f
            h += textHeight(15f) * 3 + 34f
            if (details.invoice.paidAmount > 0) h += textHeight(15f) * 2
            h += textHeight(15f) + 8f
            if (config.showTerms) h += 60f
            if (config.showSignature && !details.invoice.signaturePath.isNullOrBlank()) h += width / 3f
            h += 16f + textHeight(14f) + textHeight(11f) + 16f
            return h.toInt() + 24
        }
    }
}
