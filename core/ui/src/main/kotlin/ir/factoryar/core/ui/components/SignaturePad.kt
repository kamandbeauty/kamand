package ir.factoryar.core.ui.components

import android.graphics.Bitmap
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.Path
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp

class SignaturePadState {
    /** هر stroke: لیستی از نقاط نسبی (۰ تا ۱) */
    val strokes = mutableStateListOf<List<Offset>>()
    private var currentStroke: MutableList<Offset>? = null

    val isEmpty: Boolean get() = strokes.isEmpty()

    internal fun startStroke(relative: Offset) {
        currentStroke = mutableListOf(relative).also { strokes.add(it) }
    }

    internal fun addPoint(relative: Offset) {
        currentStroke?.add(relative)
        // force recomposition
        val idx = strokes.lastIndex
        if (idx >= 0) strokes[idx] = currentStroke.orEmpty().toList()
    }

    fun clear() {
        strokes.clear()
        currentStroke = null
    }

    /**
     * رندر روی Bitmap واقعی (برای PDF/چاپ/ذخیره فایل).
     */
    fun toBitmap(width: Int = 600, height: Int = 240): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(bitmap)
        canvas.drawColor(android.graphics.Color.WHITE)
        val paint = Paint().apply {
            color = android.graphics.Color.BLACK
            style = Paint.Style.STROKE
            strokeWidth = 5f
            isAntiAlias = true
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        strokes.forEach { stroke ->
            if (stroke.size == 1) {
                canvas.drawCircle(stroke[0].x * width, stroke[0].y * height, 3f, paint)
            } else {
                val path = Path()
                stroke.forEachIndexed { i, p ->
                    if (i == 0) path.moveTo(p.x * width, p.y * height)
                    else path.lineTo(p.x * width, p.y * height)
                }
                canvas.drawPath(path, paint)
            }
        }
        return bitmap
    }
}

@Composable
fun rememberSignaturePadState(): SignaturePadState = remember { SignaturePadState() }

/** پد امضای دیجیتال روی فاکتور */
@Composable
fun SignaturePad(
    state: SignaturePadState,
    modifier: Modifier = Modifier,
    strokeColor: Color = Color(0xFF212121),
) {
    val lineColor = MaterialTheme.colorScheme.outlineVariant
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(180.dp)
            .clip(MaterialTheme.shapes.medium),
    ) {
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(180.dp)
                .pointerInput(Unit) {
                    detectDragGestures(
                        onDragStart = { start ->
                            state.startStroke(
                                Offset(
                                    (start.x / size.width).coerceIn(0f, 1f),
                                    (start.y / size.height).coerceIn(0f, 1f),
                                ),
                            )
                        },
                    ) { change, _ ->
                        state.addPoint(
                            Offset(
                                (change.position.x / size.width).coerceIn(0f, 1f),
                                (change.position.y / size.height).coerceIn(0f, 1f),
                            ),
                        )
                    }
                },
        ) {
            // پس‌زمینه کاغذی + خط راهنما (خط امضا)
            drawRect(Color(0xFFFAFAF9))
            val dashPaint = android.graphics.Paint().apply {
                color = android.graphics.Color.LTGRAY
                strokeWidth = 2f
                pathEffect = DashPathEffect(floatArrayOf(12f, 12f), 0f)
            }
            drawContext.canvas.nativeCanvas.drawLine(24f, size.height - 44f, size.width - 24f, size.height - 44f, dashPaint)

            // امضا
            state.strokes.forEach { stroke ->
                if (stroke.size == 1) {
                    drawCircle(strokeColor, radius = 3.dp.toPx(), center = Offset(stroke[0].x * size.width, stroke[0].y * size.height))
                } else {
                    for (i in 1 until stroke.size) {
                        drawLine(
                            color = strokeColor,
                            start = Offset(stroke[i - 1].x * size.width, stroke[i - 1].y * size.height),
                            end = Offset(stroke[i].x * size.width, stroke[i].y * size.height),
                            strokeWidth = 3.dp.toPx(),
                            cap = StrokeCap.Round,
                        )
                    }
                }
            }
        }
    }
}
