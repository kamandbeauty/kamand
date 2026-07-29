package ir.factoryar.app.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import ir.factoryar.app.R
import ir.factoryar.core.common.util.PersianFormatter.toPersianDigits

/**
 * ویجت صفحه اصلی: خلاصه مالی امروز + دکمه میان‌بر «فاکتور جدید».
 * رنگ اصلی از تم انتخابی کاربر (DataStore) خوانده می‌شود و حالت روشن/تاریک را دنبال می‌کند.
 */
class FactorYarWidget : GlanceAppWidget() {

    override val sizeMode: SizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val data = WidgetDataLoader.load(context)
        provideContent { WidgetContent(data) }
    }

    @Composable
    private fun WidgetContent(data: WidgetData) {
        val context = LocalContext.current
        val primary = Color(data.primaryArgb)
        val onPrimary = if (primary.luminanceApprox() > 0.55f) Color(0xFF1B1B1F) else Color.White
        val surface = if (data.dark) Color(0xFF15181C) else Color.White
        val onSurface = if (data.dark) Color(0xFFE6E6E9) else Color(0xFF1B1B1F)
        val onSurfaceVariant = if (data.dark) Color(0xFF9EA4AC) else Color(0xFF666D75)

        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(ColorProvider(surface))
                .cornerRadius(20.dp)
                .padding(14.dp)
                .clickable(WidgetActions.openDashboard(context)),
            verticalAlignment = Alignment.Top,
        ) {
            // سربرگ: لوگو + نام کسب‌وکار + تاریخ شمسی
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Image(
                    provider = ImageProvider(R.drawable.ic_widget_logo),
                    contentDescription = null,
                    modifier = GlanceModifier.size(18.dp),
                )
                Spacer(GlanceModifier.width(6.dp))
                Text(
                    text = data.businessName.ifBlank { "فاکتوریار" },
                    style = TextStyle(
                        color = ColorProvider(onSurface),
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Medium,
                    ),
                    maxLines = 1,
                    modifier = GlanceModifier.defaultWeight(),
                )
                Text(
                    text = data.todayLabel,
                    style = TextStyle(color = ColorProvider(onSurfaceVariant), fontSize = 11.sp),
                    maxLines = 1,
                )
            }

            Spacer(GlanceModifier.height(10.dp))

            Text(
                text = "فروش امروز",
                style = TextStyle(color = ColorProvider(onSurfaceVariant), fontSize = 11.sp),
            )
            Text(
                text = data.todaySalesLabel,
                style = TextStyle(
                    color = ColorProvider(primary),
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                ),
                maxLines = 1,
            )

            Spacer(GlanceModifier.height(6.dp))

            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "معوق: ",
                    style = TextStyle(color = ColorProvider(onSurfaceVariant), fontSize = 11.sp),
                )
                Text(
                    text = "${data.overdueCount.toString().toPersianDigits()} فاکتور",
                    style = TextStyle(
                        color = ColorProvider(if (data.overdueCount > 0) Color(0xFFBA1A1A) else onSurface),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                    ),
                    modifier = GlanceModifier.clickable(WidgetActions.openInvoices(context)),
                )
                Spacer(GlanceModifier.defaultWeight())
                Text(
                    text = "${data.todayInvoiceCount.toString().toPersianDigits()} فاکتور امروز",
                    style = TextStyle(color = ColorProvider(onSurfaceVariant), fontSize = 11.sp),
                )
            }

            Spacer(GlanceModifier.height(10.dp))

            // دکمه میان‌بر: صدور فاکتور بدون باز کردن کامل اپ
            Row(
                modifier = GlanceModifier
                    .fillMaxWidth()
                    .height(38.dp)
                    .background(ColorProvider(primary))
                    .cornerRadius(12.dp)
                    .clickable(WidgetActions.newInvoice(context)),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "+ فاکتور جدید",
                    style = TextStyle(
                        color = ColorProvider(onPrimary),
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                )
            }
        }
    }
}

/** گیرنده ویجت — در AndroidManifest ثبت می‌شود */
class FactorYarWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = FactorYarWidget()
}

private fun Color.luminanceApprox(): Float = 0.299f * red + 0.587f * green + 0.114f * blue
