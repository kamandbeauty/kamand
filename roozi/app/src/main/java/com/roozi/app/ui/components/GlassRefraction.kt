package com.roozi.app.ui.components

import android.graphics.RenderEffect
import android.graphics.RuntimeShader
import android.graphics.Shader
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.compose.runtime.Immutable
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Refraction strengths for [LiquidGlassSurface], in dp so they stay physically
 * consistent across densities.
 *
 * The model is the one used by dashersw/liquid-glass-js: displacement is the
 * sum of three exponential terms keyed off the distance to the pane's edge, so
 * light bends hard right at the boundary and settles as you move inward. The
 * falloffs are per-pixel rates, which is what makes a pane read as having a
 * bevelled lip rather than a uniformly warped face.
 */
@Immutable
data class GlassRefraction(
    /** Displacement at the extreme edge. Short range, high magnitude. */
    val rim: Dp = 12.dp,
    /** Displacement across the bevel just inside the edge. */
    val edge: Dp = 5.dp,
    /**
     * Displacement across the whole face. Zero by default: on a wide, shallow
     * bar a centre warp bows the content instead of reading as glass, and the
     * upstream library leaves the equivalent switch off for the same reason.
     */
    val face: Dp = 0.dp,
    /** Extra displacement where two edges meet, where real glass is thickest. */
    val corner: Dp = 3.dp,
    /** Amplitude of the standing wave that keeps the rim from looking machined. */
    val ripple: Dp = 2.dp,
    /** Decay rate per pixel for [rim]; larger confines it closer to the edge. */
    val rimFalloff: Float = 0.8f,
    /** Decay rate per pixel for [edge]. */
    val edgeFalloff: Float = 0.15f,
    /** Growth rate per pixel for [face]. */
    val faceFalloff: Float = 0.1f,
    /** Decay rate per pixel for [corner]. */
    val cornerFalloff: Float = 0.3f
) {
    companion object {
        val Default = GlassRefraction()

        /** No displacement — blur only. */
        val None = GlassRefraction(
            rim = 0.dp, edge = 0.dp, face = 0.dp, corner = 0.dp, ripple = 0.dp
        )
    }
}

/**
 * AGSL port of the liquid-glass fragment shader.
 *
 * Differences forced by the platform, not by taste:
 *
 *  * The WebGL original runs a 13×13 gaussian in the same pass, sampling a
 *    full-page snapshot. AGSL has no such texture — `content` is only the
 *    node's own pixels — so the blur is a separate [RenderEffect] chained
 *    underneath. That is also considerably faster than 169 texture reads.
 *  * Coordinates here are pixels rather than normalised page UVs, so the
 *    displacement uniforms are absolute distances instead of fractions.
 *  * Corner radii are per-half. The header rounds only its bottom corners, and
 *    a single-radius SDF would put a phantom bevel along the top edge where
 *    the pane is actually square.
 */
private const val AGSL = """
uniform shader content;

uniform float2 size;
uniform float radiusTop;
uniform float radiusBottom;

uniform float rim;
uniform float edge;
uniform float face;
uniform float corner;
uniform float ripple;

uniform float rimFalloff;
uniform float edgeFalloff;
uniform float faceFalloff;
uniform float cornerFalloff;

// Signed distance to a rounded rectangle: negative inside, positive outside.
float roundedRectDistance(float2 p, float2 halfSize, float r) {
    float2 q = abs(p) - (halfSize - r);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

half4 main(float2 coord) {
    float2 halfSize = size * 0.5;
    float2 p = coord - halfSize;

    // Upper half uses the top radius, lower half the bottom one.
    float r = p.y < 0.0 ? radiusTop : radiusBottom;
    float dist = roundedRectDistance(p, halfSize, r);

    // Depth into the pane, in pixels. Clamped so the antialiased sliver
    // outside the shape cannot produce a negative depth and invert the falloff.
    float depth = max(-dist, 0.0);

    // Surface normal, pointing outward. Fixed direction at the exact centre,
    // where the gradient is undefined and normalize() would divide by zero.
    float2 normal = length(p) > 0.001 ? normalize(p) : float2(0.0, 1.0);

    float rimTerm = exp(-depth * rimFalloff) * rim;
    float edgeTerm = exp(-depth * edgeFalloff) * edge;
    float faceTerm = (1.0 - exp(-depth * faceFalloff)) * face;

    float2 displacement = normal * (rimTerm + edgeTerm + faceTerm);

    // Corners are thicker than flat edges, so they bend light further. Keyed
    // off the nearer axis so it only fires where two edges actually meet.
    float2 toEdge = halfSize - abs(p);
    float cornerDepth = max(toEdge.x, toEdge.y);
    displacement += normal * (exp(-cornerDepth * cornerFalloff) * corner);

    // A shallow wave along the edge, so the rim looks poured rather than cut.
    float2 tangent = float2(-normal.y, normal.x);
    displacement += tangent * (sin(depth * 0.25) * ripple * exp(-depth * rimFalloff));

    return content.eval(coord + displacement);
}
"""

/** RuntimeShader landed in API 33; RenderEffect itself in 31. */
internal val refractionSupported: Boolean
    get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU

@RequiresApi(Build.VERSION_CODES.TIRAMISU)
internal fun newRefractionShader(): RuntimeShader = RuntimeShader(AGSL)

/**
 * Blur first, then refract the blurred result.
 *
 * The order matters: refracting sharp pixels smears them into visible streaks,
 * whereas displacing an already-diffused image is what reads as thick glass.
 * `createChainEffect` applies its second argument first.
 */
@RequiresApi(Build.VERSION_CODES.TIRAMISU)
internal fun RuntimeShader.asGlassEffect(
    widthPx: Float,
    heightPx: Float,
    radiusTopPx: Float,
    radiusBottomPx: Float,
    blurPx: Float,
    refraction: GlassRefraction,
    toPx: (Dp) -> Float
): RenderEffect {
    setFloatUniform("size", widthPx, heightPx)
    setFloatUniform("radiusTop", radiusTopPx)
    setFloatUniform("radiusBottom", radiusBottomPx)

    setFloatUniform("rim", toPx(refraction.rim))
    setFloatUniform("edge", toPx(refraction.edge))
    setFloatUniform("face", toPx(refraction.face))
    setFloatUniform("corner", toPx(refraction.corner))
    setFloatUniform("ripple", toPx(refraction.ripple))

    setFloatUniform("rimFalloff", refraction.rimFalloff)
    setFloatUniform("edgeFalloff", refraction.edgeFalloff)
    setFloatUniform("faceFalloff", refraction.faceFalloff)
    setFloatUniform("cornerFalloff", refraction.cornerFalloff)

    val refract = RenderEffect.createRuntimeShaderEffect(this, "content")
    if (blurPx <= 0f) return refract

    return RenderEffect.createChainEffect(
        refract,
        RenderEffect.createBlurEffect(blurPx, blurPx, Shader.TileMode.CLAMP)
    )
}
