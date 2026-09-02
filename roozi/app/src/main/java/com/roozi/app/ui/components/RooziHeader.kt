package com.roozi.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.Image
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.roozi.app.R
import com.roozi.app.ui.theme.RooziTheme

/** Height of the sheen arc that sells the "polished glass" reading. */
private val GlassSheenHeight = 30.dp

/**
 * The app's top bar, styled as frosted glass.
 *
 * Content scrolls underneath rather than being pushed clear of it, so the bar
 * stays translucent: the page tints it as it passes. [LiquidGlassSurface]
 * supplies the real gaussian blur on API 31+; the wash, the diagonal sheen and
 * the lit edges are painted over it and carry the whole effect on the older
 * devices where the blur is unavailable.
 */
@Composable
fun RooziHeader(
    onSearch: () -> Unit,
    glass: LiquidGlassState,
    modifier: Modifier = Modifier
) {
    val colors = RooziTheme.colors
    val dark = colors.isDark

    // The wash carries the brand colour; what sits behind it is what reads as
    // glass. How much colour is needed depends on how much the surface itself
    // can do:
    //
    //  * refraction + blur — the bent, diffused backdrop already looks like a
    //    thick pane, so the wash steps back to let it show. Painting it as
    //    heavily as before would bury the effect under flat colour.
    //  * blur only — no displacement to sell thickness, so the colour carries
    //    more of the weight.
    //  * neither — opacity is all that is left.
    val hasBlur = glass.supported
    val tintAlpha = when {
        !hasBlur -> if (dark) 0.90f else 0.88f
        glass.refracts -> if (dark) 0.62f else 0.58f
        dark -> 0.80f
        else -> 0.76f
    }

    // Diagonal rather than flat: real glass picks up light unevenly across its
    // face, and an even wash is what made this read as a faded bar.
    // coerced because the stops add to the base alpha, which is now close
    // enough to 1 that they would otherwise overflow on the no-blur path.
    val wash = Brush.linearGradient(
        colorStops = arrayOf(
            0f to colors.coral.copy(alpha = (tintAlpha + 0.08f).coerceAtMost(1f)),
            0.55f to colors.purple.copy(alpha = tintAlpha),
            1f to colors.purple.copy(alpha = (tintAlpha + 0.05f).coerceAtMost(1f))
        ),
        start = Offset.Zero,
        end = Offset(0f, Float.POSITIVE_INFINITY)
    )

    // Glass is brightest where light enters and dims below; without this
    // falloff the panel reads as flat translucent plastic.
    //
    // Pulled back as the wash got deeper: over a near-solid colour the same
    // white no longer reads as a highlight on glass but as haze sitting on
    // paint, which is the opposite of the intended effect.
    val sheen = Brush.verticalGradient(
        listOf(
            Color.White.copy(alpha = if (dark) 0.22f else 0.34f),
            Color.White.copy(alpha = if (dark) 0.07f else 0.12f),
            Color.Transparent
        )
    )

    // Only the bottom is rounded — the top runs under the status bar. The
    // shader needs the two radii separately so it does not bevel the square
    // top edge as if it were curved.
    val cornerRadius = 28.dp
    val shape = RoundedCornerShape(bottomStart = cornerRadius, bottomEnd = cornerRadius)

    // Text stays white on both themes: it sits on the brand wash, not on the
    // page, so it must not follow the page's foreground colour.
    val onGlass = Color.White

    // The surface draws the refracted backdrop behind everything below it; the
    // tint, sheen and rim are then painted over that, on top of the glass.
    LiquidGlassSurface(
        state = glass,
        shape = shape,
        cornerRadiusTop = 0.dp,
        cornerRadiusBottom = cornerRadius,
        // Displacement is concentrated at the rim. The header is a wide,
        // shallow bar, so warping its face would bow the content behind it
        // rather than read as glass; the thickness cue belongs at the edges.
        refraction = GlassRefraction(
            rim = 14.dp,
            edge = 6.dp,
            face = 0.dp,
            corner = 4.dp,
            ripple = 2.dp
        ),
        modifier = modifier.fillMaxWidth()
    ) {
        Box(
            Modifier
                .matchParentSize()
                .background(wash)
                // A lit rim around the pane. Glass catches light along its
                // edges, and this is what gives the panel thickness instead of
                // looking like a coloured rectangle painted onto the page.
                //
                // Kept bright as the fill got deeper: the rim and the bottom
                // edge are now the main cues that this is a pane with
                // thickness, since the fill itself gives away less.
                .border(
                    width = 1.dp,
                    brush = Brush.verticalGradient(
                        listOf(
                            Color.White.copy(alpha = if (dark) 0.46f else 0.72f),
                            Color.White.copy(alpha = if (dark) 0.16f else 0.28f)
                        )
                    ),
                    shape = shape
                )
        )

        Box(
            Modifier
                .fillMaxWidth()
                .height(GlassSheenHeight)
                .background(sheen)
        )

        Row(
            Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(start = 20.dp, end = 12.dp, top = 6.dp, bottom = 14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // The app's own logo rather than the abstract mascot, so the header
            // matches the icon the user tapped to get here.
            // Constrained by height only: the koala is taller than it is wide,
            // and a square size() would letterbox it into a smaller figure.
            Image(
                painter = painterResource(R.drawable.ic_brand_mark),
                contentDescription = null,
                modifier = Modifier.height(38.dp)
            )

            Spacer(Modifier.width(12.dp))

            Text(
                text = stringResource(R.string.app_name_short),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = onGlass
            )

            Spacer(Modifier.weight(1f))

            // The circle is the button rather than a backdrop behind one: an
            // IconButton enforces a 48dp minimum, so nesting it here would
            // overflow the tint and clip its own ripple.
            Box(
                Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = if (dark) 0.16f else 0.26f))
                    .clickable(
                        onClick = onSearch,
                        role = Role.Button,
                        onClickLabel = stringResource(R.string.search)
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Rounded.Search,
                    contentDescription = stringResource(R.string.search),
                    tint = onGlass,
                    modifier = Modifier.size(22.dp)
                )
            }
        }

        // Lit bottom edge — the cue that separates a pane of glass from a
        // simple translucent fill.
        Box(
            Modifier
                .fillMaxWidth()
                .height(1.dp)
                .align(Alignment.BottomCenter)
                .background(Color.White.copy(alpha = if (dark) 0.20f else 0.45f))
        )
    }
}
