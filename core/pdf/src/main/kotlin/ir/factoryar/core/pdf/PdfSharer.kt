package ir.factoryar.core.pdf

import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import java.io.File

/**
 * اشتراک‌گذاری و نمایش خروجی فاکتور (PDF یا تصویر) با Intent استاندارد اندروید.
 *
 * هیچ سرور یا SDK خارجی درگیر نیست؛ کاربر از میان اپ‌های نصب‌شده
 * (تلگرام، واتساپ، ایمیل، بلوتوث و…) انتخاب می‌کند.
 */
object PdfSharer {

    private const val MIME_PDF = "application/pdf"
    private const val MIME_JPEG = "image/jpeg"

    /** تشخیص نوع محتوا از پسوند فایل */
    private fun mimeOf(file: File): String = when (file.extension.lowercase()) {
        "jpg", "jpeg" -> MIME_JPEG
        "png" -> "image/png"
        else -> MIME_PDF
    }

    private fun uriOf(context: Context, file: File) =
        FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)

    /** اشتراک یک فایل (PDF یا تصویر) */
    fun share(context: Context, file: File, title: String = "اشتراک‌گذاری فاکتور") {
        val uri = uriOf(context, file)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = mimeOf(file)
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, file.nameWithoutExtension)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val chooser = Intent.createChooser(send, title).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.packageManager.queryIntentActivities(send, 0).forEach {
            context.grantUriPermission(
                it.activityInfo.packageName,
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        }
        context.startActivity(chooser)
    }

    /**
     * اشتراک همزمان PDF و تصویر.
     * برخی پیام‌رسان‌ها تصویر را بهتر نمایش می‌دهند و برخی کاربران PDF می‌خواهند.
     */
    fun shareMultiple(context: Context, files: List<File>, title: String = "اشتراک‌گذاری فاکتور") {
        if (files.isEmpty()) return
        if (files.size == 1) return share(context, files.first(), title)

        val uris = ArrayList(files.map { uriOf(context, it) })
        val send = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
            // نوع مشترک وقتی فرمت‌ها متفاوت‌اند
            type = if (files.all { mimeOf(it) == MIME_JPEG }) MIME_JPEG else "*/*"
            putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
            putExtra(Intent.EXTRA_SUBJECT, files.first().nameWithoutExtension)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val chooser = Intent.createChooser(send, title).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.packageManager.queryIntentActivities(send, 0).forEach { info ->
            uris.forEach { uri ->
                context.grantUriPermission(
                    info.activityInfo.packageName,
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            }
        }
        context.startActivity(chooser)
    }

    /** باز کردن فایل در اپ پیش‌فرض سیستم */
    fun view(context: Context, file: File) {
        val uri = uriOf(context, file)
        val view = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeOf(file))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(
            Intent.createChooser(view, "نمایش فاکتور").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }
}
