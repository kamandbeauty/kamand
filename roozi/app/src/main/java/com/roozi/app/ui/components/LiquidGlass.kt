package com.roozi.app.ui.components

import android.os.Build
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
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
import androidx.compose.ui.graphics.asComposeRenderEffect
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.layer.GraphicsLayer
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import kotlin.math.roundToInt

/**
 * Backdrop shared between the page and the glass panes drawn over it.
 *
 * The page records itself into [layer] and the panes replay that recording,
 * blurred, to produce a refracted-looking surface.
 *
 * Crucially the page does **not** draw the layer as part of its own hierarchy;
 * it draws its content directly and treats the recording as a side copy. An
 * earlier version drew the layer in both places, which asks one GraphicsLayer
 * to belong to two parents in a single frame — the second draw is not
 * guaranteed to render anything, and on device it rendered nothing at all.
 * That is why the header stayed perfectly sharp through every previous
 * attempt, including the plain-blur fallback.
 */
@Stable
class LiquidGlassState internal constructor(internal val layer: GraphicsLayer) {

    /** Window position of the captured content. */
    internal var sourceOrigin by mutableStateOf(Offset.Zero)

    /**
     * Repaint hooks owned by the panes.
     *
     * A pane is a sibling of the page, not its parent, so scrolling the page
     * does not invalidate the pane on its own; without this it would keep
     * showing the backdrop as it looked when it last drew.
     *
     * Plain callbacks rather than snapshot state: the page signals from its
     * draw phase, and writing observable state there would schedule another
     * draw that writes again. The chain terminates because a pane never
     * invalidates the page back.
     */
    private val panes = mutableListOf<() -> Unit>()

    internal fun registerPane(invalidate: () -> Unit): () -> Unit {
        panes += invalidate
        return { panes -= invalidate }
    }

    internal fun onSourceDrawn() {
        for (i in panes.indices) panes[i].invoke()
    }

    /** Modifier.blur needs API 31; below that the pane falls back to its tint. */
    val supported: Boolean
        get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S

    /**
     * Whether the pane can also refract. RuntimeShader is API 33, so on 31–32
     * the backdrop is blurred but not displaced.
     */
    val refracts: Boolean
        get() = refractionSupported
}

@Composable
fun rememberLiquidGlassState(): LiquidGlassState {
    val layer = rememberGraphicsLayer()
    return remember(layer) { LiquidGlassState(layer) }
}

/**
 * Marks the content the glass samples.
 *
 * Records a copy into the shared layer, then draws the content normally. The
 * copy exists purely for the panes to replay; the page itself never renders
 * through it.
 */
fun Modifier.liquidGlassSource(state: LiquidGlassState): Modifier = this
    .onGloballyPositioned { state.sourceOrigin = it.positionInWindow() }
    .drawWithContent {
        // The ContentDrawScope must be captured before entering record's
        // lambda: inside it the receiver is a plain DrawScope with no
        // drawContent().
        val scope = this
        state.layer.record(
            density = this,
            layoutDirection = layoutDirection,
            size = IntSize(size.width.roundToInt(), size.height.roundToInt())
        ) { scope.drawContent() }

        // Draw the page itself, not the recording — see the note on
        // LiquidGlassState about a layer having a single parent.
        drawContent()
        state.onSourceDrawn()
    }

/**
 * A pane of Liquid Glass: the refracted, blurred backdrop, then [content].
 *
 * On API 33+ the backdrop passes through an AGSL shader that displaces it
 * towards the pane's edges — the effect that makes a surface look like a solid
 * piece of glass rather than a frosted window. Below that it is blur only,
 * which is why the header still paints its own tint, sheen and rim: those are
 * what carry the look where the shader cannot run.
 *
 * The offscreen buffer comes from `graphicsLayer`/`Modifier.blur` rather than a
 * hand-managed one. An earlier attempt set the effect on a GraphicsLayer we
 * owned; the framework honours a RenderEffect only on its own RenderNode, so
 * nothing was ever filtered.
 */
@Composable
fun LiquidGlassSurface(
    state: LiquidGlassState,
    shape: Shape,
    modifier: Modifier = Modifier,
    radius: Dp = 24.dp,
    refraction: GlassRefraction = GlassRefraction.Default,
    cornerRadiusTop: Dp = 0.dp,
    cornerRadiusBottom: Dp = 28.dp,
    content: @Composable BoxScope.() -> Unit
) {
    var origin by remember { mutableStateOf(Offset.Zero) }

    var repaint by remember { mutableIntStateOf(0) }
    DisposableEffect(state) {
        val unregister = state.registerPane { repaint++ }
        onDispose { unregister() }
    }

    // Constructing a RuntimeShader below API 33 would throw, so it is built
    // only where it is usable.
    //
    // The version check is written out here rather than delegated to
    // state.refracts: lint resolves SDK_INT comparisons syntactically and
    // cannot see through a property getter, so the indirection made every call
    // below look unguarded.
    val shader = remember(state.refracts) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            newRefractionShader()
        } else {
            null
        }
    }

    Box(modifier.clip(shape)) {
        if (state.supported) {
            val density = LocalDensity.current
            Box(
                Modifier
                    .matchParentSize()
                    .onGloballyPositioned { origin = it.positionInWindow() }
                    .then(
                        if (shader != null &&
                            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                        ) {
                            Modifier.graphicsLayer {
                                // Zero-area layers happen for a frame during
                                // layout; a shader sized 0×0 divides by zero
                                // and renders nothing.
                                if (size.width < 1f || size.height < 1f) {
                                    return@graphicsLayer
                                }
                                renderEffect = shader.asGlassEffect(
                                    widthPx = size.width,
                                    heightPx = size.height,
                                    radiusTopPx = cornerRadiusTop.toPx(),
                                    radiusBottomPx = cornerRadiusBottom.toPx(),
                                    blurPx = radius.toPx(),
                                    refraction = refraction,
                                    toPx = { with(density) { it.toPx() } }
                                ).asComposeRenderEffect()
                            }
                        } else {
                            // API 31–32: blur alone, via the supported API.
                            Modifier.blur(radius, BlurredEdgeTreatment.Unbounded)
                        }
                    )
                    .drawBehind {
                        // Read so a page repaint re-runs this block, keeping the
                        // pane in step with whatever scrolls behind it.
                        @Suppress("UNUSED_EXPRESSION") repaint

                        // An unrecorded layer has no display list; drawing it
                        // would throw.
                        if (state.layer.size.width == 0 || state.layer.size.height == 0) {
                            return@drawBehind
                        }
                        // The recording covers the whole page, so shift it by
                        // this pane's offset within that page; otherwise the
                        // glass would show the page's top-left corner instead
                        // of what actually sits behind it.
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
