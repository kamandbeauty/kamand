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
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.BlurredEdgeTreatment
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Shape
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
 * position, blurred and refracted.
 */
@Stable
class LiquidGlassState internal constructor(internal val layer: GraphicsLayer) {

    /** Window position of the captured content. */
    internal var sourceOrigin by mutableStateOf(Offset.Zero)

    /**
     * Redraws registered by glass panes.
     *
     * The glass is a sibling of the page, not its parent, so scrolling the page
     * does not invalidate the header on its own — without this the pane would
     * keep showing whatever the backdrop looked like when it last drew.
     *
     * These are plain callbacks rather than snapshot state on purpose: the page
     * signals them from its draw phase, and writing observable state there
     * would schedule another draw, which writes again — an endless loop.
     */
    private val panes = mutableListOf<() -> Unit>()

    internal fun registerPane(invalidate: () -> Unit): () -> Unit {
        panes += invalidate
        return { panes -= invalidate }
    }

    internal fun onSourceDrawn() {
        for (i in panes.indices) panes[i].invoke()
    }

    /** Modifier.blur needs API 31; below that glass falls back to its tint. */
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
        state.onSourceDrawn()
    }

/**
 * A pane of Liquid Glass: draws the blurred backdrop, then [content] on top.
 *
 * The blur is `Modifier.blur`, not a RenderEffect assigned by hand. Several
 * earlier attempts set the effect manually and it silently never applied — the
 * page stayed perfectly sharp through the pane. This modifier is the supported
 * path and manages its own offscreen buffer, which is what those attempts were
 * missing.
 *
 * The refraction shader is layered on top of it where AGSL exists (API 33+),
 * via graphicsLayer *after* blur so it distorts an already-frosted image.
 */
@Composable
fun LiquidGlassSurface(
    state: LiquidGlassState,
    shape: Shape,
    modifier: Modifier = Modifier,
    radius: Dp = 24.dp,
    content: @Composable BoxScope.() -> Unit
) {
    var origin by remember { mutableStateOf(Offset.Zero) }

    // Compiling an AGSL program is expensive, so the refractor is created once
    // and only its uniforms change per frame.
    val refractor = remember {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // RuntimeShader throws if the AGSL fails to compile, and some GPU
            // drivers reject programs the spec allows. Falling back to plain
            // blur is a cosmetic downgrade; letting it propagate would take the
            // whole app down at startup.
            runCatching { GlassRefractor() }.getOrNull()
        } else {
            null
        }
    }

    // Drives the rim ripple and the specular sweep.
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

    // Bumped from the page's draw callback; read in drawBehind below so the
    // pane repaints as the page scrolls underneath it.
    var repaint by remember { mutableIntStateOf(0) }
    DisposableEffect(state) {
        val unregister = state.registerPane { repaint++ }
        onDispose { unregister() }
    }

    Box(modifier.clip(shape)) {
        if (state.blurSupported) {
            Spacer(
                Modifier
                    .matchParentSize()
                    .onGloballyPositioned { origin = it.positionInWindow() }
                    // Refraction sits outermost so it warps the blurred result.
                    .graphicsLayer {
                        // Spelled out rather than relying on refractor being
                        // null below API 33: lint cannot follow that
                        // implication and flags the call as unguarded.
                        if (
                            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                            refractor != null
                        ) {
                            renderEffect = refractor.effect(
                                width = size.width,
                                height = size.height,
                                time = time,
                                sheen = if (still) 0f else SHEEN_STRENGTH
                            )
                        }
                    }
                    .blur(radius, BlurredEdgeTreatment(shape))
                    .drawBehind {
                        // Read so a page repaint re-runs this block, keeping the
                        // glass in step with what is scrolling behind it.
                        @Suppress("UNUSED_EXPRESSION") repaint
                        // A layer that was never recorded has no display list
                        // to sample, and drawing it would throw.
                        if (state.layer.size.width == 0 || state.layer.size.height == 0) {
                            return@drawBehind
                        }
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
