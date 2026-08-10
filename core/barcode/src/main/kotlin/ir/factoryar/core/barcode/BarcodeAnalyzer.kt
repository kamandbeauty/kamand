package ir.factoryar.core.barcode

import android.graphics.ImageFormat
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import com.google.zxing.BinaryBitmap
import com.google.zxing.DecodeHintType
import com.google.zxing.MultiFormatReader
import com.google.zxing.NotFoundException
import com.google.zxing.PlanarYUVLuminanceSource
import com.google.zxing.common.HybridBinarizer
import java.util.EnumMap
import java.util.concurrent.atomic.AtomicBoolean

/** موتور اسکن مورد استفاده — برای نمایش به کاربر و عیب‌یابی */
enum class ScanEngine { ZXING }

/**
 * تحلیلگر فریم دوربین برای تشخیص بارکد — بر پایهٔ ZXing.
 *
 * چرا ZXing و نه ML Kit؟
 *   • مدل bundled کتابخانهٔ ML Kit حدود ۱۰ تا ۱۵ مگابایت به حجم APK اضافه
 *     می‌کرد. برای اپی که رقبایش در کافه‌بازار ۶ مگابایت هستند، این هزینه
 *     برای قابلیتی جانبی توجیه ندارد.
 *   • ZXing خالص جاواست (حدود ۵۰۰ کیلوبایت)، به Google Play Services نیاز
 *     ندارد و روی همهٔ دستگاه‌های بازار ایران کار می‌کند.
 *   • برای بارکد کالا (EAN/UPC/Code-128) دقت ZXing کاملاً کافی است.
 *
 * اگر اسکن با دوربین ممکن نباشد (نبود دوربین یا رد مجوز)، UI امکان ورود
 * دستی بارکد را می‌دهد.
 */
class BarcodeAnalyzer(
    private val onResult: (value: String, format: String, engine: ScanEngine) -> Unit,
) : ImageAnalysis.Analyzer {

    private val handled = AtomicBoolean(false)

    private val reader by lazy {
        MultiFormatReader().apply {
            val hints = EnumMap<DecodeHintType, Any>(DecodeHintType::class.java)
            hints[DecodeHintType.TRY_HARDER] = true
            setHints(hints)
        }
    }

    /** پس از یک تشخیص موفق، تحلیل متوقف می‌شود تا نتیجهٔ تکراری صادر نشود */
    fun reset() = handled.set(false)

    override fun analyze(imageProxy: ImageProxy) {
        if (handled.get()) {
            imageProxy.close()
            return
        }
        try {
            decode(imageProxy)
        } finally {
            imageProxy.close()
        }
    }

    private fun decode(imageProxy: ImageProxy) {
        if (imageProxy.format != ImageFormat.YUV_420_888) return
        runCatching {
            val plane = imageProxy.planes[0]
            val data = ByteArray(plane.buffer.remaining()).also { plane.buffer.get(it) }
            val source = PlanarYUVLuminanceSource(
                data,
                plane.rowStride,
                imageProxy.height,
                0,
                0,
                imageProxy.width.coerceAtMost(plane.rowStride),
                imageProxy.height,
                false,
            )
            val bitmap = BinaryBitmap(HybridBinarizer(source))
            val result = try {
                reader.decodeWithState(bitmap)
            } catch (e: NotFoundException) {
                null
            }
            result?.text?.takeIf { it.isNotBlank() }?.let { text ->
                if (handled.compareAndSet(false, true)) {
                    onResult(text.trim(), result.barcodeFormat.name, ScanEngine.ZXING)
                }
            }
        }
        reader.reset()
    }
}
