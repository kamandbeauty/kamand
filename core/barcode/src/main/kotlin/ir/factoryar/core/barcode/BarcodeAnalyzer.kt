package ir.factoryar.core.barcode

import android.annotation.SuppressLint
import android.graphics.ImageFormat
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.google.zxing.BinaryBitmap
import com.google.zxing.DecodeHintType
import com.google.zxing.MultiFormatReader
import com.google.zxing.NotFoundException
import com.google.zxing.PlanarYUVLuminanceSource
import com.google.zxing.common.HybridBinarizer
import java.util.EnumMap
import java.util.concurrent.atomic.AtomicBoolean

/** موتور اسکن مورد استفاده — برای نمایش به کاربر و عیب‌یابی */
enum class ScanEngine { ML_KIT, ZXING }

/**
 * تحلیلگر فریم دوربین برای تشخیص بارکد.
 *
 * استراتژی سازگاری با دستگاه‌های بدون Google Play Services:
 *  ۱. ML Kit نسخه bundled (مدل داخل APK) — نیازی به GMS ندارد.
 *  ۲. اگر ML Kit در دسترس نبود یا خطا داد، به‌صورت خودکار به موتور ZXING سوییچ می‌شود.
 *  ۳. اگر دوربین/اسکن اصلاً کار نکرد، UI امکان ورود دستی بارکد را می‌دهد.
 */
class BarcodeAnalyzer(
    private val onResult: (value: String, format: String, engine: ScanEngine) -> Unit,
) : ImageAnalysis.Analyzer {

    private val handled = AtomicBoolean(false)

    /** در صورت خطای ML Kit به ZXing سوییچ می‌کنیم */
    @Volatile
    private var useMlKit: Boolean = MlKitAvailability.isAvailable

    private val mlScanner: BarcodeScanner? by lazy {
        runCatching {
            BarcodeScanning.getClient(
                BarcodeScannerOptions.Builder()
                    .setBarcodeFormats(
                        Barcode.FORMAT_EAN_13,
                        Barcode.FORMAT_EAN_8,
                        Barcode.FORMAT_UPC_A,
                        Barcode.FORMAT_UPC_E,
                        Barcode.FORMAT_CODE_128,
                        Barcode.FORMAT_CODE_39,
                        Barcode.FORMAT_CODE_93,
                        Barcode.FORMAT_ITF,
                        Barcode.FORMAT_QR_CODE,
                        Barcode.FORMAT_DATA_MATRIX,
                    )
                    .build(),
            )
        }.getOrNull()
    }

    private val zxingReader by lazy {
        MultiFormatReader().apply {
            val hints = EnumMap<DecodeHintType, Any>(DecodeHintType::class.java)
            hints[DecodeHintType.TRY_HARDER] = true
            setHints(hints)
        }
    }

    /** پس از یک تشخیص موفق، تحلیل متوقف می‌شود تا نتیجه تکراری صادر نشود */
    fun reset() = handled.set(false)

    @SuppressLint("UnsafeOptInUsageError")
    override fun analyze(imageProxy: ImageProxy) {
        if (handled.get()) {
            imageProxy.close()
            return
        }

        val scanner = mlScanner
        if (useMlKit && scanner != null) {
            val mediaImage = imageProxy.image
            if (mediaImage == null) {
                imageProxy.close()
                return
            }
            val input = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
            scanner.process(input)
                .addOnSuccessListener { barcodes ->
                    barcodes.firstOrNull { !it.rawValue.isNullOrBlank() }?.let { barcode ->
                        if (handled.compareAndSet(false, true)) {
                            onResult(barcode.rawValue!!.trim(), formatName(barcode.format), ScanEngine.ML_KIT)
                        }
                    }
                }
                .addOnFailureListener {
                    // ML Kit در این دستگاه کار نمی‌کند → سوییچ دائمی به ZXing
                    useMlKit = false
                }
                .addOnCompleteListener { imageProxy.close() }
        } else {
            decodeWithZxing(imageProxy)
            imageProxy.close()
        }
    }

    private fun decodeWithZxing(imageProxy: ImageProxy) {
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
                zxingReader.decodeWithState(bitmap)
            } catch (e: NotFoundException) {
                zxingReader.reset()
                null
            }
            result?.text?.takeIf { it.isNotBlank() }?.let { text ->
                if (handled.compareAndSet(false, true)) {
                    onResult(text.trim(), result.barcodeFormat.name, ScanEngine.ZXING)
                }
            }
        }
        zxingReader.reset()
    }

    private fun formatName(format: Int): String = when (format) {
        Barcode.FORMAT_EAN_13 -> "EAN-13"
        Barcode.FORMAT_EAN_8 -> "EAN-8"
        Barcode.FORMAT_UPC_A -> "UPC-A"
        Barcode.FORMAT_UPC_E -> "UPC-E"
        Barcode.FORMAT_CODE_128 -> "CODE-128"
        Barcode.FORMAT_CODE_39 -> "CODE-39"
        Barcode.FORMAT_QR_CODE -> "QR"
        Barcode.FORMAT_DATA_MATRIX -> "DataMatrix"
        else -> "بارکد"
    }
}

/** تشخیص اینکه آیا کلاس‌های ML Kit در رانتایم قابل بارگذاری‌اند */
object MlKitAvailability {
    val isAvailable: Boolean by lazy {
        runCatching {
            Class.forName("com.google.mlkit.vision.barcode.BarcodeScanning")
            true
        }.getOrDefault(false)
    }
}
