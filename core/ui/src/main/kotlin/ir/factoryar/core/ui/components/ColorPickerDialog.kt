package ir.factoryar.core.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import androidx.core.graphics.ColorUtils

/**
 * انتخاب‌گر رنگ آزاد (HSV): مربع اشباع/روشنایی + نوار Hue + ورودی Hex.
 * قابلیت اشتراک طلایی.
 */
@Composable
fun ColorPickerDialog(
    initialArgb: Long,
    onDismiss: () -> Unit,
    onConfirm: (Long) -> Unit,
) {
    val initialHsl = remember {
        FloatArray(3).also { ColorUtils.colorToHSL(initialArgb.toInt(), it) }
    }
    var hue by remember { mutableFloatStateOf(initialHsl[0]) }
    var sat by remember { mutableFloatStateOf(initialHsl[1].coerceIn(0.15f, 1f)) }
    var light by remember { mutableFloatStateOf(initialHsl[2].coerceIn(0.25f, 0.75f)) }
    var hexText by remember { mutableStateOf("%06X".format(initialArgb.toInt() and 0xFFFFFF)) }

    val currentColor = Color(ColorUtils.HSLToColor(floatArrayOf(hue, sat, light)))

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("انتخاب رنگ دلخواه", style = MaterialTheme.typography.titleMedium) },
        text = {
            Column {
                // پیش‌نمایش
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        Modifier
                            .size(52.dp)
                            .clip(CircleShape)
                            .background(currentColor)
                            .border(1.dp, MaterialTheme.colorScheme.outline, CircleShape),
                    )
                    Spacer(Modifier.width(12.dp))
                    OutlinedTextField(
                        value = hexText,
                        onValueChange = { input ->
                            val cleaned = input.filter { it.isDigit() || it.lowercaseChar() in 'a'..'f' }.take(6)
                            hexText = cleaned.uppercase()
                            if (cleaned.length == 6) {
                                runCatching {
                                    val argb = android.graphics.Color.parseColor("#$cleaned")
                                    val hsl = FloatArray(3).also { ColorUtils.colorToHSL(argb, it) }
                                    hue = hsl[0]; sat = hsl[1].coerceIn(0.15f, 1f); light = hsl[2].coerceIn(0.25f, 0.75f)
                                }
                            }
                        },
                        label = { Text("کد رنگ (Hex)") },
                        singleLine = true,
                        modifier = Modifier.weight(1f),
                    )
                }
                Spacer(Modifier.height(16.dp))

                // مربع اشباع × روشنایی
                val svGradientH = remember(hue) {
                    Brush.horizontalGradient(listOf(Color.White, Color(ColorUtils.HSLToColor(floatArrayOf(hue, 1f, 0.5f)))))
                }
                val svGradientV = remember { Brush.verticalGradient(listOf(Color.Transparent, Color.Black)) }
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(160.dp)
                        .clip(MaterialTheme.shapes.medium),
                ) {
                    Canvas(
                        Modifier
                            .fillMaxWidth()
                            .height(160.dp)
                            .pointerInput(Unit) {
                                detectTapGestures { offset ->
                                    sat = (offset.x / size.width).coerceIn(0.15f, 1f)
                                    light = (1f - offset.y / size.height).coerceIn(0.25f, 0.75f)
                                }
                            }
                            .pointerInput(Unit) {
                                detectDragGestures { change, _ ->
                                    sat = (change.position.x / size.width).coerceIn(0.15f, 1f)
                                    light = (1f - change.position.y / size.height).coerceIn(0.25f, 0.75f)
                                }
                            },
                    ) {
                        drawRect(svGradientH)
                        drawRect(svGradientV)
                        // نشانگر موقعیت
                        val cx = sat * size.width
                        val cy = (1f - light) * size.height
                        drawCircle(Color.White, radius = 12.dp.toPx(), center = Offset(cx, cy))
                        drawCircle(Color(0x66000000), radius = 12.dp.toPx(), center = Offset(cx, cy), style = androidx.compose.ui.graphics.drawscope.Stroke(2.dp.toPx()))
                    }
                }
                Spacer(Modifier.height(12.dp))

                // نوار Hue
                val hueBrush = remember {
                    Brush.horizontalGradient((0..6).map { Color(ColorUtils.HSLToColor(floatArrayOf(it * 60f, 1f, 0.5f))) })
                }
                Canvas(
                    Modifier
                        .fillMaxWidth()
                        .height(24.dp)
                        .clip(CircleShape)
                        .pointerInput(Unit) {
                            detectTapGestures { offset -> hue = (offset.x / size.width).coerceIn(0f, 1f) * 360f }
                        }
                        .pointerInput(Unit) {
                            detectDragGestures { change, _ -> hue = (change.position.x / size.width).coerceIn(0f, 1f) * 360f }
                        },
                ) {
                    drawRect(hueBrush)
                    val cx = (hue / 360f) * size.width
                    drawCircle(Color.White, radius = 10.dp.toPx(), center = Offset(cx, size.height / 2))
                    drawCircle(Color(0x66000000), radius = 10.dp.toPx(), center = Offset(cx, size.height / 2), style = androidx.compose.ui.graphics.drawscope.Stroke(2.dp.toPx()))
                }
            }
        },
        confirmButton = {
            TextButton(onClick = { onConfirm(0xFF000000L or (currentColor.toArgb().toLong() and 0xFFFFFF)) }) {
                Text("اعمال رنگ")
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )
}
