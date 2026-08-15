package com.roozi.app.ui.components

import androidx.compose.foundation.background
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
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
 * is deliberately translucent: the page tints it as it passes. A real gaussian
 * blur is not used because Modifier.blur needs API 31 and minSdk here is 24 —
 * the frost is faked instead with a translucent brand wash, a diagonal sheen
 * across the top and a bright hairline along the bottom edge, which is what
 * actually reads as glass at this size.
 */
@Composable
fun RooziHeader(
    onSearch: () -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = RooziTheme.colors
    val dark = colors.isDark

    // Frosted, not merely see-through. Real glass diffuses what is behind it;
    // with no blur available the same effect has to come from opacity, so this
    // is tuned to leave the page a soft ghost rather than legible text that
    // would collide with the title scrolling past underneath.
    val wash = Brush.horizontalGradient(
        listOf(
            colors.coral.copy(alpha = if (dark) 0.80f else 0.76f),
            colors.purple.copy(alpha = if (dark) 0.80f else 0.76f)
        )
    )

    // Glass is brightest where light enters and dims below; without this
    // falloff the panel reads as flat translucent plastic.
    val sheen = Brush.verticalGradient(
        listOf(
            Color.White.copy(alpha = if (dark) 0.14f else 0.30f),
            Color.Transparent
        )
    )

    val shape = RoundedCornerShape(bottomStart = 28.dp, bottomEnd = 28.dp)

    // Text stays white on both themes: it sits on the brand wash, not on the
    // page, so it must not follow the page's foreground colour.
    val onGlass = Color.White

    Box(
        modifier
            .fillMaxWidth()
            .clip(shape)
            .background(wash)
    ) {
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
            RooziMascot(size = 34.dp, blink = false)

            Spacer(Modifier.width(12.dp))

            Text(
                text = stringResource(R.string.app_name),
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
