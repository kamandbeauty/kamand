package ir.javid.hesabyar.feature.invoices

import android.content.Context
import android.graphics.Color
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.net.Uri
import androidx.core.content.FileProvider
import dagger.hilt.android.qualifiers.ApplicationContext
import ir.javid.hesabyar.core.common.PersianDate
import ir.javid.hesabyar.core.common.PersianNumbers
import ir.javid.hesabyar.core.model.InvoiceDocument
import javax.inject.Inject

/** Creates a shareable, device-local PDF. No invoice information leaves the phone automatically. */
class InvoicePdfExporter @Inject constructor(@ApplicationContext private val context: Context) {
    fun export(invoice: InvoiceDocument): Result<Uri> = runCatching {
        val dir = context.cacheDir.resolve("invoices").apply { mkdirs() }
        val safeNumber = invoice.invoiceNumber.replace(Regex("[^\p{L}\p{N}_.-]"), "_")
        val file = dir.resolve("$safeNumber.pdf")
        val pdf = PdfDocument()
        try {
            val page = pdf.startPage(PdfDocument.PageInfo.Builder(595, 842, 1).create())
            val canvas = page.canvas
            val title = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(0, 96, 80); textSize = 22f; textAlign = Paint.Align.RIGHT; isFakeBoldText = true }
            val normal = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.DKGRAY; textSize = 12f; textAlign = Paint.Align.RIGHT }
            val bold = Paint(normal).apply { isFakeBoldText = true }
            var y = 55f
            canvas.drawText("حسابیار جاوید", 560f, y, title)
            y += 32
            canvas.drawText("${if (invoice.kind.name == "SALE") "فاکتور فروش" else "فاکتور خرید"}  |  ${invoice.invoiceNumber}", 560f, y, bold)
            y += 22
            canvas.drawText("تاریخ: ${PersianDate.format(invoice.dateEpochDay)}", 560f, y, normal)
            y += 20
            canvas.drawText("طرف حساب: ${invoice.partyName ?: "نقدی"}", 560f, y, normal)
            y += 22
            canvas.drawLine(35f, y, 560f, y, normal)
            y += 22
            canvas.drawText("کالا / خدمت", 560f, y, bold)
            canvas.drawText("تعداد", 375f, y, bold)
            canvas.drawText("قیمت", 260f, y, bold)
            canvas.drawText("جمع", 105f, y, bold)
            y += 12
            canvas.drawLine(35f, y, 560f, y, normal)
            invoice.lines.take(24).forEach { line ->
                y += 22
                canvas.drawText(line.name.take(30), 560f, y, normal)
                canvas.drawText(PersianNumbers.quantity(line.quantity), 375f, y, normal)
                canvas.drawText(PersianNumbers.amountWithoutCurrency(line.unitPrice), 260f, y, normal)
                canvas.drawText(PersianNumbers.amountWithoutCurrency(line.total), 105f, y, normal)
            }
            y += 24
            canvas.drawLine(35f, y, 560f, y, normal)
            y += 23
            listOf("جمع" to invoice.subtotal, "تخفیف" to invoice.discount, "مالیات" to invoice.tax, "مبلغ نهایی" to invoice.total, "پرداخت" to invoice.paid, "مانده" to invoice.balance).forEach { (label, amount) ->
                canvas.drawText(label, 560f, y, if (label == "مبلغ نهایی") bold else normal)
                canvas.drawText(PersianNumbers.amount(amount), 250f, y, if (label == "مبلغ نهایی") bold else normal)
                y += 20
            }
            if (invoice.notes.isNotBlank()) { y += 8; canvas.drawText("توضیحات: ${invoice.notes.take(60)}", 560f, y, normal) }
            canvas.drawText("این فاکتور به‌صورت آفلاین توسط حسابیار جاوید ایجاد شده است.", 560f, 810f, Paint(normal).apply { textSize = 9f })
            pdf.finishPage(page)
            file.outputStream().use { pdf.writeTo(it) }
        } finally { pdf.close() }
        FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
    }
}
