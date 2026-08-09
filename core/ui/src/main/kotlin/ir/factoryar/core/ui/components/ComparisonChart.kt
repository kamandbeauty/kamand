package ir.factoryar.core.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.unit.dp

/** یک سری داده در نمودار مقایسه‌ای */
data class ChartSeries(
    val label: String,
    val color: Color,
    val values: List<Long>,
)

/**
 * نمودار میله‌ای گروهی برای مقایسه درآمد / هزینه / سود خالص.
 * مقادیر منفی (زیان) زیر خط صفر رسم می‌شوند.
 */
@Composable
fun ComparisonBarChart(
    labels: List<String>,
    series: List<ChartSeries>,
    modifier: Modifier = Modifier,
    height: androidx.compose.ui.unit.Dp = 190.dp,
) {
    if (labels.isEmpty() || series.isEmpty()) return
    val gridColor = MaterialTheme.colorScheme.outlineVariant
    val axisLabelColor = MaterialTheme.colorScheme.onSurfaceVariant

    Column(modifier) {
        // راهنمای رنگ‌ها
        Row(
            modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            series.forEach { s ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        Modifier
                            .size(10.dp)
                            .background(s.color, RoundedCornerShape(3.dp)),
                    )
                    Spacer(Modifier.width(4.dp))
                    Text(
                        s.label,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }

        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(height),
        ) {
            val allValues = series.flatMap { it.values }
            val maxValue = (allValues.maxOrNull() ?: 0L).coerceAtLeast(0L)
            val minValue = (allValues.minOrNull() ?: 0L).coerceAtMost(0L)
            val span = (maxValue - minValue).coerceAtLeast(1L).toFloat()

            val labelHeight = 22.dp.toPx()
            val plotHeight = size.height - labelHeight
            // موقعیت خط صفر
            val zeroY = plotHeight * (maxValue.toFloat() / span)

            // خطوط شبکه
            repeat(4) { i ->
                val y = plotHeight * i / 3f
                drawLine(
                    color = gridColor,
                    start = Offset(0f, y),
                    end = Offset(size.width, y),
                    strokeWidth = 1f,
                    pathEffect = PathEffect.dashPathEffect(floatArrayOf(8f, 8f)),
                )
            }
            // خط صفر پررنگ‌تر
            drawLine(
                color = gridColor,
                start = Offset(0f, zeroY),
                end = Offset(size.width, zeroY),
                strokeWidth = 2f,
            )

            val groupWidth = size.width / labels.size
            val barGap = 2.dp.toPx()
            val barWidth = ((groupWidth - barGap * (series.size + 1)) / series.size)
                .coerceAtLeast(2f)
                .coerceAtMost(28.dp.toPx())

            labels.indices.forEach { index ->
                val groupStart = groupWidth * index +
                    (groupWidth - (barWidth * series.size + barGap * (series.size - 1))) / 2

                series.forEachIndexed { sIndex, s ->
                    val value = s.values.getOrElse(index) { 0L }
                    val ratio = value.toFloat() / span
                    val barHeight = kotlin.math.abs(ratio) * plotHeight
                    val left = groupStart + sIndex * (barWidth + barGap)
                    val top = if (value >= 0) zeroY - barHeight else zeroY
                    drawRoundRect(
                        color = s.color,
                        topLeft = Offset(left, top),
                        size = Size(barWidth, barHeight.coerceAtLeast(2f)),
                        cornerRadius = CornerRadius(4f, 4f),
                    )
                }

                // برچسب محور افقی
                drawContext.canvas.nativeCanvas.drawText(
                    labels[index],
                    groupWidth * index + groupWidth / 2,
                    size.height - 5.dp.toPx(),
                    android.graphics.Paint().apply {
                        textSize = 9.dp.toPx()
                        textAlign = android.graphics.Paint.Align.CENTER
                        color = android.graphics.Color.GRAY
                        isAntiAlias = true
                    },
                )
            }
        }
    }
}
