package com.roozi.app.ui.components

import android.os.Build
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.LinearEasing
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlurEffect
import androidx.compose.ui.graphics.TileMode
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.layer.GraphicsLayer
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.roozi.app.ui.rememberReduceMotion
import kotlin.math.PI
import kotlin.math.roundToInt

/**
 * Shared backdrop for Liquid Glass surfaces.
 *
 * A translucent tint only dims what is behind it; glass has to actually
 * *resample* the backdrop. So the page paints itself once into an offscreen
 * layer, and every glass surface re-draws that layer — shifted to its own
 * position and blurred — which is what produces the smeared, refracted look
 * instead of a flat wash.
 */
@Stable
class LiquidGlassState internal constructor(internal val layer: GraphicsLayer) {

    /** Window position of the captured content. */
    internal var sourceOrigin by mutableStateOf(Offset.Zero)

    /** RenderEffect needs API 31; below that glass falls back to its tint. */
    internal val blurSupported: Boolean
        get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
}

@Composable
fun rememberLiquidGlassState(): LiquidGlassState {
    val layer = rememberGraphicsLayer()
    return remember(layer) { LiquidGlassState(layer) }
}

/**
 * Marks the content whose pixels the glass refracts.
 *
 * The drawing is recorded into the shared layer and immediately drawn back, so
 * the page looks unchanged while leaving a copy for the glass to sample. The
 * layer itself never carries a RenderEffect — the page must stay sharp.
 */
fun Modifier.liquidGlassSource(state: LiquidGlassState): Modifier = this
    .onGloballyPositioned { state.sourceOrigin = it.positionInWindow() }
    .drawWithContent {
        // The ContentDrawScope has to be captured before entering record's
        // lambda: inside it the receiver is a plain DrawScope, which has no
        // drawContent().
        val scope = this
        // GraphicsLayer.record with explicit density/layoutDirection/size. The
        // shorter DrawScope.record(layer) overload is not present across all
        // Compose 1.7.x releases, so the long form is used deliberately.
        state.layer.record(
            density = this,
            layoutDirection = layoutDirection,
            size = IntSize(size.width.roundToInt(), size.height.roundToInt())
        ) { scope.drawContent() }
        drawLayer(state.layer)
    }

/**
 * Modifier that draws the blurred, offset backdrop behind a glass surface.
 *
 * Apply to the panel itself: it renders the backdrop first, then the panel's
 * own content on top.
 *
 * The blur lives on a second layer owned by this surface, which re-draws the
 * shared one. Setting the effect on the shared layer instead would blur the
 * page itself, since that is the very layer the page paints with — the reason
 * an earlier attempt produced no glass at all.
 *
 * @param radius blur strength — larger reads as thicker, more frosted glass.
 */
@Composable
fun liquidGlassBackdrop(
    state: LiquidGlassState,
    radius: Dp = 30.dp
): Modifier {
    var origin by remember { mutableStateOf(Offset.Zero) }
    val glassLayer = rememberGraphicsLayer()

    // Compiling an AGSL program is expensive, so the refractor is created once
    // and only its uniforms change per frame.
    val refractor = remember {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) GlassRefractor() else null
    }

    // Drives the rim ripple and the specular sweep. Held as State and read
    // inside the draw phase, so the animation redraws the header without
    // recomposing it every frame.
    val still = rememberReduceMotion()
    val transition = rememberInfiniteTransition(label = "liquidGlass")
    val time by if (still) {
        remember { mutableFloatStateOf(0f) }
    } else {
        transition.animateFloat(
            initialValue = 0f,
            // A whole number of ripple periods, so the loop restart is seamless
            // rather than jumping mid-wave.
            targetValue = (2f * PI).toFloat() / 1.8f * RIPPLE_LOOPS,
            animationSpec = infiniteRepeatable(
                animation = tween(RIPPLE_PERIOD_MS, easing = LinearEasing),
                repeatMode = RepeatMode.Restart
            ),
            label = "glassTime"
        )
    }

    return Modifier
        .onGloballyPositioned { origin = it.positionInWindow() }
        .drawWithContent {
            // A layer that was never recorded has no display list to sample;
            // reading its size is how that is detected without writing
            // snapshot state from the draw phase, which would not reliably
            // invalidate this surface anyway.
            val ready = state.layer.size.width > 0 && state.layer.size.height > 0

            if (state.blurSupported && ready && size.minDimension > 0f) {
                val r = radius.toPx()
                // Refraction where AGSL exists (API 33+), plain frost below it.
                // Decal stops the edges sampling repeated copies of the
                // backdrop, which would ghost along the panel's borders.
                glassLayer.renderEffect = refractor?.effect(
                    width = size.width,
                    height = size.height,
                    blurRadius = r,
                    time = time,
                    sheen = if (still) 0f else SHEEN_STRENGTH
                ) ?: BlurEffect(r, r, TileMode.Decal)
                glassLayer.record(
                    density = this,
                    layoutDirection = layoutDirection,
                    size = IntSize(size.width.roundToInt(), size.height.roundToInt())
                ) {
                    // The shared layer holds the whole page, so shift it by
                    // this panel's offset within that page; otherwise the glass
                    // would show the page's top-left corner rather than what is
                    // actually behind it.
                    translate(
                        left = state.sourceOrigin.x - origin.x,
                        top = state.sourceOrigin.y - origin.y
                    ) {
                        drawLayer(state.layer)
                    }
                }
                drawLayer(glassLayer)
            }
            drawContent()
        }
}

/** Number of ripple periods per animation loop; keeps the restart seamless. */
private const val RIPPLE_LOOPS = 6f

private const val RIPPLE_PERIOD_MS = 21_000

/** Strength of the moving specular highlight. */
private const val SHEEN_STRENGTH = 0.10f
