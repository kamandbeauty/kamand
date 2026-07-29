package ir.factoryar.core.pdf

import android.content.Context
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import ir.factoryar.core.common.jalali.JalaliConverter
import ir.factoryar.core.common.util.PersianFormatter.formatMoney
import ir.factoryar.core.common.util.PersianFormatter.toPersianDigits
import ir.factoryar.core.domain.model.SalesReport
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream

/** خروجی PDF گزارش فروش — قابلیت اشتراک طلایی */
class ReportPdfGenerator(private val context: Context) {

    companion object {
        private const val PAGE_W = 595
        private const val PAGE_H = 842
        private const val MARGIN = 40f
    }

    suspend fun generate(report: SalesReport): File = withContext(Dispatchers.IO) {
        val doc = PdfDocument()
        val page = doc.startPage(PdfDocument.PageInfo.Builder(PAGE_W, PAGE_H, 1).create())
        val canvas = page.canvas

        val right = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = Paint.Align.RIGHT
            color = Color.BLACK
        }
        val center = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = Paint.Align.CENTER
            color = Color.BLACK
        }

        var y = MARGIN + 10f
        right.textSize = 18f
        right.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        canvas.drawText("گزارش فروش — فاکتوریار", PAGE_W - MARGIN, y, right)

        y += 26f
        right.textSize = 11f
        right.typeface = Typeface.DEFAULT
        right.color = Color.DKGRAY
        val from = JalaliConverter.fromEpochMillis(report.from).format().toPersianDigits()
        val to = JalaliConverter.fromEpochMillis(report.to).format().toPersianDigits()
        canvas.drawText("از $from تا $to", PAGE_W - MARGIN, y, right)

        y += 26f
        val line = Paint().apply { color = Color.LTGRAY; strokeWidth = 1f }
        canvas.drawLine(MARGIN, y, PAGE_W - MARGIN, y, line)
        y += 20f

        fun row(label: String, value: String) {
            right.textSize = 12f
            right.color = Color.BLACK
            canvas.drawText(label, PAGE_W - MARGIN, y, right)
            right.textAlign = Paint.Align.LEFT
            canvas.drawText(value, MARGIN, y, right)
            right.textAlign = Paint.Align.RIGHT
            y += 24f
        }

        row("تعداد فاکتور فروش:", report.invoiceCount.toString().toPersianDigits())
        row("جمع فروش:", formatMoney(report.totalSales))
        row("جمع خرید:", formatMoney(report.totalPurchase))
        row("سود ناخالص:", formatMoney(report.grossProfit))
        row("دریافت‌شده:", formatMoney(report.paidAmount))
        row("دریافت‌نشده:", formatMoney(report.unpaidAmount))
        row("مبالغ معوق:", formatMoney(report.overdueAmount))

        y += 12f
        canvas.drawLine(MARGIN, y, PAGE_W - MARGIN, y, line)
        y += 20f
        right.textSize = 13f
        right.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        canvas.drawText("فروش روزانه", PAGE_W - MARGIN, y, right)
        right.typeface = Typeface.DEFAULT
        y += 18f

        val maxBar = (PAGE_W - 2 * MARGIN - 130f)
        val maxValue = (report.dailySales.maxOfOrNull { it.second } ?: 1L).coerceAtLeast(1L).toFloat()
        report.dailySales.takeLast(31).forEach { (day, total) ->
            val d = JalaliConverter.fromEpochMillis(day)
            val label = "${d.year}/${d.month}/${d.day}".toPersianDigits()
            right.textSize = 9f
            right.color = Color.DKGRAY
            canvas.drawText(label, PAGE_W - MARGIN, y + 9f, right)
            val barW = maxBar * (total / maxValue)
            val barPaint = Paint().apply { color = 0xFF1E5AA8.toInt() }
            canvas.drawRect(PAGE_W - MARGIN - 95f - barW, y, PAGE_W - MARGIN - 95f, y + 12f, barPaint)
            right.color = Color.BLACK
            right.textSize = 8f
            right.textAlign = Paint.Align.LEFT
            canvas.drawText(formatMoney(total), MARGIN, y + 9f, right)
            right.textAlign = Paint.Align.RIGHT
            y += 20f
            if (y > PAGE_H - 60f) return@forEach
        }

        center.textSize = 8.5f
        center.color = Color.parseColor("#9AA0A6")
        canvas.drawText("گزارش حرفه‌ای فاکتوریار — اشتراک طلایی", PAGE_W / 2f, PAGE_H - 24f, center)

        doc.finishPage(page)
        val dir = File(context.getExternalFilesDir(null) ?: context.filesDir, "reports").apply { mkdirs() }
        val file = File(dir, "sales_report_${System.currentTimeMillis()}.pdf")
        FileOutputStream(file).use { doc.writeTo(it) }
        doc.close()
        file
    }
}
