package com.roozi.app.ui.components

import android.graphics.RenderEffect
import android.graphics.RuntimeShader
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.compose.ui.graphics.asComposeRenderEffect
import androidx.compose.ui.graphics.RenderEffect as ComposeRenderEffect

/**
 * AGSL refraction pass for the Liquid Glass surfaces.
 *
 * Blur alone is frost, not glass: light passing through a real pane is *bent*,
 * and the bending is wavelength dependent. This shader supplies both, which is
 * what separates a glass panel from a blurred rectangle.
 *
 *  - a lens bulge that grows towards the bottom rim, so content approaching the
 *    edge of the pane visibly warps rather than simply softening;
 *  - chromatic aberration along the same gradient — the red and blue channels
 *    are sampled a fraction apart, reproducing the colour fringing that real
 *    refractive dispersion produces at a glass edge.
 *
 * Coordinates arrive in pixels local to the filtered layer, hence the explicit
 * division by `size`.
 */
private const val REFRACTION_AGSL = """
uniform shader content;
uniform float2 size;
uniform float aberration;
uniform float bulge;
uniform float time;
uniform float sheen;

half4 main(float2 fragCoord) {
    float2 uv = fragCoord / size;

    // Refraction is concentrated at the rim; the middle of a pane is close to
    // flat, so distortion there would just look like a wobbly image.
    float distFromBottom = 1.0 - uv.y;
    float rim = 1.0 - smoothstep(0.0, 0.38, distFromBottom);

    // Centre sits just past the bottom edge so the bulge pushes outward
    // through the rim rather than radiating from the middle of the header.
    float2 toCentre = uv - float2(0.5, 1.05);
    float dist = length(toCentre);
    float2 dir = toCentre / max(dist, 0.0001);
    float push = rim * bulge * (1.0 - smoothstep(0.0, 0.9, dist));

    // A slow travelling ripple along the rim, so the glass reads as liquid
    // rather than a fixed lens. Amplitude is a fraction of the bulge; any
    // larger and the text behind it visibly wobbles.
    float ripple = sin(uv.x * 14.0 - time * 1.8) * 0.0022 * rim;

    float2 warped = clamp(uv + dir * push + float2(0.0, ripple), 0.0, 1.0) * size;

    // Split the channels across the same rim gradient. Green stays put and
    // carries the alpha, so the image keeps its position and coverage.
    float split = aberration * rim * size.x;
    half4 centre = content.eval(warped);
    half red = content.eval(clamp(warped + float2(split, 0.0), float2(0.0), size)).r;
    half blue = content.eval(clamp(warped - float2(split, 0.0), float2(0.0), size)).b;

    half4 color = half4(red, centre.g, blue, centre.a);

    // Specular highlight sweeping across the pane. Multiplied by alpha so it
    // cannot paint light onto fully transparent pixels outside the panel.
    float sweep = fract(uv.x - time * 0.12);
    float band = smoothstep(0.42, 0.5, sweep) * smoothstep(0.58, 0.5, sweep);
    color.rgb += half3(band * sheen * float(centre.a));

    // The lit lip along the bottom edge where the pane catches light.
    float lip = smoothstep(0.05, 0.0, distFromBottom);
    color.rgb += half3(lip * 0.16 * float(centre.a));

    return color;
}
"""

/**
 * Builds the refraction effect.
 *
 * RuntimeShader is API 33, two levels above RenderEffect itself, so this is
 * kept separate from the caller and only instantiated behind a version check.
 * Compiling the program is expensive, so the instance is reused and only its
 * uniforms are updated.
 */
@RequiresApi(Build.VERSION_CODES.TIRAMISU)
internal class GlassRefractor {

    private val shader = RuntimeShader(REFRACTION_AGSL)

    /**
     * @param time seconds, driving the rim ripple and the specular sweep. Pass
     *   a constant to hold the glass still.
     * @param sheen strength of the moving highlight; 0 disables it.
     */
    fun effect(
        width: Float,
        height: Float,
        time: Float,
        sheen: Float
    ): ComposeRenderEffect {
        shader.setFloatUniform("size", width, height)
        shader.setFloatUniform("aberration", ABERRATION)
        shader.setFloatUniform("bulge", BULGE)
        shader.setFloatUniform("time", time)
        shader.setFloatUniform("sheen", sheen)

        // No blur is chained here: Modifier.blur supplies it, and this effect
        // is installed outside that modifier so it warps the frosted result.
        return RenderEffect
            .createRuntimeShaderEffect(shader, "content")
            .asComposeRenderEffect()
    }

    private companion object {
        /** Fraction of width the red/blue channels separate by at the rim. */
        const val ABERRATION = 0.0016f

        /** Peak lens displacement at the rim, in UV units. */
        const val BULGE = 0.030f
    }
}
