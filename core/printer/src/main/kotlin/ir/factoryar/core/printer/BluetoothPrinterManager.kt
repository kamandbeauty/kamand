package ir.factoryar.core.printer

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.graphics.Bitmap
import ir.factoryar.core.common.util.AppResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.IOException
import java.util.UUID

data class PrinterDevice(val name: String, val macAddress: String)

/**
 * اتصال و چاپ روی چاپگرهای پوز/حرارتی بلوتوثی پروتکل ESC/POS (SPP سریال).
 * چاپ به‌صورت Raster Image (G S v 0) چون متن فارسی فونت داخلی چاپگر ندارد.
 */
class BluetoothPrinterManager(private val context: Context) {

    companion object {
        private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    }

    private val bluetoothAdapter by lazy {
        (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
    }

    val isBluetoothAvailable: Boolean get() = bluetoothAdapter != null

    @SuppressLint("MissingPermission") // مجوز در UI گرفته می‌شود
    fun pairedPrinters(): List<PrinterDevice> = runCatching {
        bluetoothAdapter?.bondedDevices.orEmpty()
            .filter { it.bluetoothClass.majorDeviceClass == android.bluetooth.BluetoothClass.Device.Major.IMAGING || it.type == BluetoothDevice.DEVICE_TYPE_CLASSIC }
            .map { PrinterDevice(it.name ?: "چاپگر", it.address) }
    }.getOrDefault(emptyList())

    /** چاپ یک Bitmap روی چاپگر MAC داده شده */
    suspend fun print(macAddress: String, bitmap: Bitmap): AppResult<Unit> = withContext(Dispatchers.IO) {
        var socket: BluetoothSocket? = null
        try {
            val adapter = bluetoothAdapter ?: return@withContext AppResult.Failure("بلوتوث روی این دستگاه وجود ندارد")
            @SuppressLint("MissingPermission")
            val device = adapter.getRemoteDevice(macAddress) ?: return@withContext AppResult.Failure("چاپگر یافت نشد")
            @SuppressLint("MissingPermission")
            run { adapter.cancelDiscovery() }
            @SuppressLint("MissingPermission")
            socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
            @SuppressLint("MissingPermission")
            run { socket!!.connect() }
            val out = socket!!.outputStream

            // ESC @ — ریست چاپگر
            out.write(byteArrayOf(0x1B, 0x40))
            // تصویر را به قطعه‌های ۲۵۶ پیکسلی ارتفاع تقسیم می‌کنیم که بافر چاپگر پر نشود
            val chunkHeight = 256
            var offsetY = 0
            while (offsetY < bitmap.height) {
                val h = minOf(chunkHeight, bitmap.height - offsetY)
                val chunk = Bitmap.createBitmap(bitmap, 0, offsetY, bitmap.width, h)
                out.write(EscPosEncoder.encodeRaster(chunk))
                chunk.recycle()
                offsetY += h
            }
            // فاصله پایان چاپ + برش ناقص
            out.write(byteArrayOf(0x1B, 0x64, 0x05)) // feed 5 lines
            out.write(byteArrayOf(0x1D, 0x56, 0x42, 0x00)) // GS V partial cut
            out.flush()
            AppResult.Success(Unit)
        } catch (e: SecurityException) {
            AppResult.Failure("مجوز بلوتوث داده نشده است", e)
        } catch (e: IOException) {
            AppResult.Failure("اتصال به چاپگر برقرار نشد: ${e.message}", e)
        } finally {
            runCatching { socket?.close() }
        }
    }
}

/** تبدیل Bitmap به دستورات ESC/POS GS v 0 */
object EscPosEncoder {

    fun encodeRaster(bitmap: Bitmap): ByteArray {
        val width = bitmap.width
        val height = bitmap.height
        val bytesPerRow = (width + 7) / 8

        val header = byteArrayOf(
            0x1D, 0x76, 0x30, 0x00, // GS v 0, mode 0 (normal)
            (bytesPerRow and 0xFF).toByte(), ((bytesPerRow shr 8) and 0xFF).toByte(),
            (height and 0xFF).toByte(), ((height shr 8) and 0xFF).toByte(),
        )
        val body = ByteArray(bytesPerRow * height)
        val pixels = IntArray(width)
        for (y in 0 until height) {
            bitmap.getPixels(pixels, 0, width, 0, y, width, 1)
            for (xByte in 0 until bytesPerRow) {
                var b = 0
                for (bit in 0 until 8) {
                    val x = xByte * 8 + bit
                    if (x < width) {
                        val p = pixels[x]
                        val r = (p shr 16) and 0xFF
                        val g = (p shr 8) and 0xFF
                        val bl = p and 0xFF
                        val luminance = (r * 299 + g * 587 + bl * 114) / 1000
                        if (luminance < 128) b = b or (0x80 shr bit)
                    }
                }
                body[y * bytesPerRow + xByte] = b.toByte()
            }
        }
        return header + body
    }
}
