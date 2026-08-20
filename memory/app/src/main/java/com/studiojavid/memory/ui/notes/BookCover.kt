package com.studiojavid.memory.ui.notes

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.studiojavid.memory.ui.components.darken
import com.studiojavid.memory.ui.theme.MemoryTheme

/**
 * A notebook drawn as an actual little book: a coloured cover, a darker spine
 * with binding bands, page edges peeking out and a soft highlight.
 *
 * Drawn on a Canvas rather than assembled from Boxes so the spine, pages and
 * cover stay in proportion at any size, and so it can't drift from the design
 * as layout code changes around it.
 */
@Composable
fun BookCover(
    color: Color,
    modifier: Modifier = Modifier,
    width: Dp = 84.dp,
    height: Dp = 104.dp,
    selected: Boolean = false,
    onClick: (() -> Unit)? = null
) {
    val scale by animateFloatAsState(
        targetValue = if (selected) 1.04f else 1f,
        animationSpec = spring(dampingRatio = 0.55f, stiffness = 420f),
        label = "bookScale"
    )

    Box(
        modifier = modifier
            .size(width, height)
            .scale(scale)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier),
        contentAlignment = Alignment.Center
    ) {
        Canvas(Modifier.size(width, height)) {
            val w = size.width
            val h = size.height
            val spineW = w * 0.17f
            val radius = CornerRadius(w * 0.10f, w * 0.10f)

            // Page block, offset so the paper edge shows along the fore-edge.
            drawRoundRect(
                color = Color(0xFFF7F3EC),
                topLeft = Offset(spineW * 0.6f, h * 0.045f),
                size = Size(w - spineW * 0.6f - w * 0.02f, h * 0.91f),
                cornerRadius = radius
            )
            // Faint page lines for depth.
            repeat(3) { i ->
                val y = h * (0.16f + i * 0.055f)
                drawLine(
                    color = Color(0x22000000),
                    start = Offset(w - w * 0.06f, y),
                    end = Offset(w - w * 0.02f, y),
                    strokeWidth = h * 0.006f
                )
            }

            // Cover
            drawRoundRect(
                brush = Brush.linearGradient(
                    listOf(color, color.darken(0.18f)),
                    start = Offset(0f, 0f),
                    end = Offset(w, h)
                ),
                topLeft = Offset(0f, 0f),
                size = Size(w - w * 0.10f, h),
                cornerRadius = radius
            )

            // Spine: a darker strip with two binding bands.
            drawRoundRect(
                color = color.darken(0.34f),
                topLeft = Offset(0f, 0f),
                size = Size(spineW, h),
                cornerRadius = CornerRadius(w * 0.10f, w * 0.10f)
            )
            listOf(0.24f, 0.72f).forEach { t ->
                drawLine(
                    color = Color(0x33FFFFFF),
                    start = Offset(spineW * 0.18f, h * t),
                    end = Offset(spineW * 0.82f, h * t),
                    strokeWidth = h * 0.012f
                )
            }

            // A blank label plate: gives the cover structure without an icon.
            val plateW = (w - spineW) * 0.56f
            val plateH = h * 0.30f
            drawRoundRect(
                color = Color(0x1FFFFFFF),
                topLeft = Offset(spineW + (w - w * 0.10f - spineW - plateW) / 2f, h * 0.24f),
                size = Size(plateW, plateH),
                cornerRadius = CornerRadius(w * 0.045f, w * 0.045f)
            )

            // Gloss: a soft diagonal highlight across the cover.
            val gloss = Path().apply {
                moveTo(w * 0.30f, 0f)
                lineTo(w * 0.58f, 0f)
                lineTo(w * 0.20f, h)
                lineTo(w * 0.02f, h)
                close()
            }
            drawPath(gloss, Color(0x14FFFFFF))
        }


    }
}

/** A book plus its title and note count — one item on the shelf. */
@Composable
fun BookShelfItem(
    title: String,
    subtitle: String,
    color: Color,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = MemoryTheme.colors
    Column(
        modifier = modifier.width(92.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // The cover is drawn bare: an emblem floating on it read as a sticker
        // stuck to the book rather than part of it.
        BookCover(color = color, selected = selected, onClick = onClick)
        Spacer(Modifier.height(8.dp))
        Text(
            text = title,
            style = MaterialTheme.typography.labelLarge,
            color = if (selected) colors.textPrimary else colors.textSecondary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center
        )
        // Blank for shelves that have nothing worth counting, so the row keeps
        // an even baseline without inventing a caption.
        if (subtitle.isNotBlank()) {
            Text(
                text = subtitle,
                style = MaterialTheme.typography.labelSmall,
                color = colors.textSecondary.copy(alpha = 0.75f),
                maxLines = 1,
                textAlign = TextAlign.Center
            )
        }
    }
}
