package com.roozi.app.ui.components

import android.os.Build
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlurEffect
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.TileMode
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.graphicsLayer
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
 * position, blurred and refracted — which is what produces the smeared,
 * bent look instead of a flat wash.
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
        state.layer.record(
            density = this,
            layoutDirection = layoutDirection,
            size = IntSize(size.width.roundToInt(), size.height.roundToInt())
        ) { scope.drawContent() }
        drawLayer(state.layer)
    }

/**
 * A pane of Liquid Glass: draws the refracted backdrop, then [content] on top.
 *
 * The effect is installed with `Modifier.graphicsLayer { renderEffect = … }` on
 * a dedicated child that sits *behind* the content. Two reasons this shape is
 * required rather than incidental:
 *
 *  - the framework's own RenderNode is what actually honours a RenderEffect;
 *    an earlier version set the effect on a hand-managed GraphicsLayer and it
 *    silently never applied, which is why the header stayed sharp;
 *  - a graphicsLayer wraps everything drawn after it, so if the backdrop and
 *    the content shared one layer the title and icons would blur too.
 */
@Composable
fun LiquidGlassSurface(
    state: LiquidGlassState,
    shape: Shape,
    modifier: Modifier = Modifier,
    radius: Dp = 30.dp,
    content: @Composable BoxScope.() -> Unit
) {
    var origin by remember { mutableStateOf(Offset.Zero) }

    // Compiling an AGSL program is expensive, so the refractor is created once
    // and only its uniforms change per frame.
    val refractor = remember {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) GlassRefractor() else null
    }

    // Drives the rim ripple and the specular sweep. Read inside the layer block,
    // which re-runs on each draw, so the animation never recomposes the header.
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

    Box(modifier.clip(shape)) {
        if (state.blurSupported) {
            Spacer(
                Modifier
                    .matchParentSize()
                    .onGloballyPositioned { origin = it.positionInWindow() }
                    // graphicsLayer must precede drawBehind so the layer wraps
                    // it: the effect filters what the modifiers *after* it
                    // draw. Reversed, the backdrop would be painted outside the
                    // layer and pass through untouched.
                    .graphicsLayer {
                        val r = radius.toPx()
                        renderEffect = refractor?.effect(
                            width = size.width,
                            height = size.height,
                            blurRadius = r,
                            time = time,
                            sheen = if (still) 0f else SHEEN_STRENGTH
                        ) ?: BlurEffect(r, r, TileMode.Decal)
                    }
                    .drawBehind {
                        // A layer that was never recorded has no display list
                        // to sample, and drawing it would throw.
                        if (state.layer.size.width == 0 || state.layer.size.height == 0) return@drawBehind
                        // The shared layer holds the whole page, so shift it by
                        // this pane's offset within that page; otherwise the
                        // glass would show the page's top-left corner rather
                        // than what is actually behind it.
                        translate(
                            left = state.sourceOrigin.x - origin.x,
                            top = state.sourceOrigin.y - origin.y
                        ) {
                            drawLayer(state.layer)
                        }
                    }
            )
        }
        content()
    }
}

/** Number of ripple periods per animation loop; keeps the restart seamless. */
private const val RIPPLE_LOOPS = 6f

private const val RIPPLE_PERIOD_MS = 21_000

/** Strength of the moving specular highlight. */
private const val SHEEN_STRENGTH = 0.10f
