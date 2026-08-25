package com.modir.forushgah.presentation.invoice

import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.provider.MediaStore
import android.view.View
import android.view.ViewGroup
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.ComposeView
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileOutputStream
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext

/**
 * Rubi invoice output (spec §11): the invoice is captured as a high-quality
 * PNG of the same composables shown on screen (no second template), then
 * shared / saved. Rubi's «ارسال PDF» is a high-res image for printing — the
 * same approach is kept.
 */
object InvoiceImageExporter {

    /** 1080px wide ≈ 360dp @3x, matching Rubi's pixelRatio: 3 capture. */
    const val OUTPUT_WIDTH_PX = 1080
    const val OUTPUT_DENSITY = 3f

    /**
     * Renders [content] into an invisible [ComposeView] attached to the
     * activity window and draws it into a bitmap (the pre-ViewRenderer
     * capture path — this ui version has no ViewRenderer).
     */
    suspend fun renderInvoice(context: Context, content: @Composable () -> Unit): Bitmap {
        val activity = context as? Activity ?: error("renderInvoice requires an Activity context")
        return withContext(Dispatchers.Main) {
            val composeView = ComposeView(activity).apply {
                alpha = 0f
                visibility = View.INVISIBLE
                setContent { content() }
            }
            val container = activity.window.decorView as ViewGroup
            container.addView(composeView, ViewGroup.LayoutParams(OUTPUT_WIDTH_PX, ViewGroup.LayoutParams.WRAP_CONTENT))
            try {
                // let the composition lay out and dispatch two frames so the
                // first real frame is drawn before we capture it
                suspendCancellableCoroutine { cont ->
                    cont.invokeOnCancellation { container.removeView(composeView) }
                    var frames = 0
                    fun pump() {
                        composeView.post {
                            frames++
                            if (frames < 2) pump() else if (cont.isActive) cont.resume(Unit)
                        }
                    }
                    pump()
                }
                val w = composeView.width.coerceAtLeast(1)
                val h = composeView.height.coerceAtLeast(1)
                val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                composeView.draw(Canvas(bitmap))
                bitmap
            } finally {
                container.removeView(composeView)
            }
        }
    }

    /** Writes the PNG into app-internal storage and returns a shareable URI. */
    fun writePng(context: Context, invoiceNumber: String, bitmap: Bitmap): Uri {
        val dir = File(context.filesDir, "invoices").apply { mkdirs() }
        val file = File(dir, "factor-${invoiceNumber}-${System.currentTimeMillis()}.png")
        FileOutputStream(file).use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        }
        return FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
    }

    /** System share sheet with the Rubi share text + subject. */
    fun shareImage(context: Context, uri: Uri, text: String, subject: String) {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TEXT, text)
            putExtra(Intent.EXTRA_SUBJECT, subject)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(
            Intent.createChooser(intent, "اشتراک‌گذاری فاکتور").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    /** Share the high-res image with the Rubi print/PDF caption. */
    fun sharePdfLike(context: Context, uri: Uri, text: String, subject: String) {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TEXT, "$text\n\n(نسخه تصویری فاکتور برای چاپ/PDF)")
            putExtra(Intent.EXTRA_SUBJECT, "$subject PDF")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(
            Intent.createChooser(intent, "اشتراک‌گذاری فاکتور").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    /** Save to the device gallery (MediaStore — no permission needed on 29+). */
    fun saveToGallery(context: Context, invoiceNumber: String, bitmap: Bitmap): Boolean {
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, "factor-$invoiceNumber.png")
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
        }
        val uri = context.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values) ?: return false
        return try {
            context.contentResolver.openOutputStream(uri)?.use {
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
            }
            true
        } catch (e: Exception) {
            false
        }
    }
}
