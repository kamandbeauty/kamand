package ir.factoryar.core.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.unit.dp
import ir.factoryar.core.common.util.PersianFormatter.formatMoney

/** نمودار میله‌ای سبک (روزانه/ماهانه) — بدون وابستگی کتابخانه‌ای */
@Composable
fun SimpleBarChart(
    values: List<Pair<String, Long>>, // برچسب → مقدار
    modifier: Modifier = Modifier,
    barColor: Color = MaterialTheme.colorScheme.primary,
    highlightLast: Boolean = true,
) {
    val gridColor = MaterialTheme.colorScheme.outlineVariant
    val labelColor = MaterialTheme.colorScheme.onSurfaceVariant
    if (values.isEmpty()) return

    androidx.compose.foundation.layout.Column(modifier) {
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(160.dp),
        ) {
            val maxValue = (values.maxOf { it.second }).coerceAtLeast(1).toFloat()
            val barAreaHeight = size.height - 28.dp.toPx()
            val slot = size.width / values.size
            val barWidth = (slot * 0.55f).coerceAtMost(64.dp.toPx())

            // خطوط شبکه
            repeat(4) { i ->
                val y = barAreaHeight * i / 3f
                drawLine(
                    color = gridColor,
                    start = Offset(0f, y),
                    end = Offset(size.width, y),
                    strokeWidth = 1f,
                    pathEffect = PathEffect.dashPathEffect(floatArrayOf(8f, 8f)),
                )
            }

            values.forEachIndexed { index, (_, value) ->
                val centerX = slot * index + slot / 2
                val barHeight = (barAreaHeight) * (value.toFloat() / maxValue)
                val top = barAreaHeight - barHeight
                val color = if (highlightLast && index == values.lastIndex) barColor else barColor.copy(alpha = 0.55f)
                drawRoundRect(
                    color = color,
                    topLeft = Offset(centerX - barWidth / 2, top),
                    size = Size(barWidth, barHeight.coerceAtLeast(4f)),
                    cornerRadius = CornerRadius(8f, 8f),
                )
                // مقدار روی میله آخر
                if (index == values.lastIndex && value > 0) {
                    drawContext.canvas.nativeCanvas.drawText(
                        formatMoney(value),
                        centerX,
                        (top - 8f).coerceAtLeast(14f),
                        android.graphics.Paint().apply {
                            textSize = 11.dp.toPx()
                            textAlign = android.graphics.Paint.Align.CENTER
                            this.color = android.graphics.Color.GRAY
                            isAntiAlias = true
                        },
                    )
                }
                // برچسب زیر محور
                drawContext.canvas.nativeCanvas.drawText(
                    values[index].first,
                    centerX,
                    size.height - 6.dp.toPx(),
                    android.graphics.Paint().apply {
                        textSize = 10.dp.toPx()
                        textAlign = android.graphics.Paint.Align.CENTER
                        this.color = android.graphics.Color.GRAY
                        isAntiAlias = true
                    },
                )
            }
        }
    }
}
