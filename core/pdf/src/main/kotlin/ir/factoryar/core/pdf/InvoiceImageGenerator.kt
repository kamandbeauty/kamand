package ir.factoryar.core.pdf

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import ir.factoryar.core.common.util.CurrencyUnit
import ir.factoryar.core.domain.model.BusinessProfile
import ir.factoryar.core.domain.model.InvoiceWithDetails
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream

/**
 * تولید خروجی تصویری (JPG) از فاکتور.
 *
 * روش کار: به‌جای بازنویسی کل منطق رسم، همان PDF تولیدشده توسط
 * [InvoicePdfGenerator] با `PdfRenderer` اندروید به تصویر تبدیل می‌شود.
 * مزیت این روش:
 *   • خروجی JPG دقیقاً همان چیدمان PDF را دارد (یک منبع حقیقت)
 *   • هر اصلاحی در طراحی فاکتور خودکار در هر دو خروجی اعمال می‌شود
 *   • نیازی به نگهداری دو موتور رسم جداگانه نیست
 *
 * برای فاکتورهای چندصفحه‌ای، صفحات به‌صورت عمودی به هم چسبانده می‌شوند
 * تا کاربر یک تصویر یکپارچه برای ارسال در پیام‌رسان داشته باشد.
 */
class InvoiceImageGenerator(private val context: Context) {

    companion object {
        /** ضریب بزرگ‌نمایی نسبت به اندازهٔ A4 در PDF — کیفیت مناسب برای نمایش و چاپ خانگی */
        private const val SCALE = 2
        private const val JPEG_QUALITY = 92

        /** فاصلهٔ سفید بین صفحات در تصویر یکپارچه */
        private const val PAGE_GAP_PX = 24
    }

    /**
     * ساخت تصویر JPG از فاکتور.
     *
     * @param pdfFile اگر PDF از قبل ساخته شده، برای جلوگیری از کار دوباره پاس داده شود
     */
    suspend fun generate(
        details: InvoiceWithDetails,
        profile: BusinessProfile,
        currencyUnit: CurrencyUnit,
        showWatermark: Boolean,
        pdfFile: File? = null,
    ): File = withContext(Dispatchers.IO) {
        val source = pdfFile ?: InvoicePdfGenerator(context).generate(
            details = details,
            profile = profile,
            currencyUnit = currencyUnit,
            showWatermark = showWatermark,
        )

        val bitmap = renderPdfToBitmap(source)
        val dir = File(context.getExternalFilesDir(null) ?: context.filesDir, "images").apply { mkdirs() }
        val name = details.invoice.number.ifBlank { details.invoice.id.toString() }
        val out = File(dir, "invoice_$name.jpg")

        FileOutputStream(out).use { stream ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, stream)
        }
        bitmap.recycle()
        out
    }

    /** تبدیل همهٔ صفحات PDF به یک بیت‌مپ عمودی یکپارچه */
    private fun renderPdfToBitmap(pdf: File): Bitmap {
        ParcelFileDescriptor.open(pdf, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
            PdfRenderer(descriptor).use { renderer ->
                val pageCount = renderer.pageCount.coerceAtLeast(1)
                val pages = mutableListOf<Bitmap>()

                try {
                    for (index in 0 until pageCount) {
                        renderer.openPage(index).use { page ->
                            val w = page.width * SCALE
                            val h = page.height * SCALE
                            val pageBitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                            // JPEG شفافیت ندارد؛ پس‌زمینه سفید لازم است
                            Canvas(pageBitmap).drawColor(Color.WHITE)
                            page.render(pageBitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                            pages += pageBitmap
                        }
                    }

                    if (pages.size == 1) return pages.first()

                    // چسباندن عمودی صفحات
                    val width = pages.maxOf { it.width }
                    val height = pages.sumOf { it.height } + PAGE_GAP_PX * (pages.size - 1)
                    val combined = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(combined).apply { drawColor(Color.WHITE) }
                    var top = 0f
                    pages.forEach { p ->
                        canvas.drawBitmap(p, 0f, top, null)
                        top += p.height + PAGE_GAP_PX
                    }
                    return combined
                } finally {
                    // در حالت تک‌صفحه، همان بیت‌مپ بازگردانده شده پس نباید آزاد شود
                    if (pages.size > 1) pages.forEach { it.recycle() }
                }
            }
        }
    }
}
