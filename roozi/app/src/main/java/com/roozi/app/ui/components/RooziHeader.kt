package com.roozi.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.roozi.app.R
import com.roozi.app.ui.theme.RooziTheme

/**
 * The app's top bar.
 *
 * Previously this was a fully transparent [androidx.compose.material3.TopAppBar],
 * so the app name and the search icon sat directly on the scrolling page with
 * nothing behind them — they read as loose elements floating in space, and list
 * content slid underneath them. This gives them a real surface: a brand gradient
 * band, rounded at the bottom so it reads as a header rather than a slab, with
 * the title anchored next to the mark and the search action inside a tinted
 * circle so it looks like a button instead of a stray glyph.
 */
@Composable
fun RooziHeader(
    onSearch: () -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = RooziTheme.colors

    // Slightly deeper than the page gradient it sits on, so the band separates
    // from the content without needing a shadow.
    val band = Brush.linearGradient(
        colors = listOf(colors.coral, colors.purple),
        start = Offset.Zero,
        end = Offset.Infinite
    )

    Box(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(bottomStart = 26.dp, bottomEnd = 26.dp))
            .background(band)
    ) {
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
                color = Color.White
            )

            Spacer(Modifier.weight(1f))

            // The circle is the button rather than a backdrop behind one: an
            // IconButton enforces a 48dp minimum, so nesting it here would
            // overflow the tint and clip its own ripple.
            Box(
                Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.20f))
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
                    tint = Color.White,
                    modifier = Modifier.size(22.dp)
                )
            }
        }
    }
}
