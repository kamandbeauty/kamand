package com.studiojavid.diary.ui.components

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.PhotoCamera
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.studiojavid.diary.R
import com.studiojavid.diary.data.local.Mood
import com.studiojavid.diary.data.repo.DiaryPage
import com.studiojavid.diary.ui.theme.DiaryTheme
import java.io.File

/**
 * One diary page as a card.
 *
 * The mood colour is the card's accent, so a scrolled month reads as a mood
 * timeline before a single word is read.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun DiaryPageCard(
    page: DiaryPage,
    dateLabel: String,
    photo: File?,
    onClick: () -> Unit,
    onToggleFavorite: () -> Unit,
    modifier: Modifier = Modifier,
    onLongClick: (() -> Unit)? = null
) {
    val colors = DiaryTheme.colors
    val accent = page.mood.color().takeIf { page.mood != Mood.UNSET } ?: colors.purple

    DiaryCard(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .combinedClickable(onClick = onClick, onLongClick = onLongClick),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp)
    ) {
        Row(Modifier.fillMaxWidth()) {
            // Mood rail: a full-height colour bar rather than a dot, so the
            // accent survives being scanned at arm's length.
            Box(
                Modifier
                    .width(6.dp)
                    .height(if (page.hasPhoto) 168.dp else 96.dp)
                    .background(accent)
            )
            Column(Modifier.padding(14.dp).fillMaxWidth()) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (page.mood != Mood.UNSET) {
                        Text(page.mood.emoji, fontSize = 18.sp)
                        Spacer(Modifier.width(8.dp))
                    }
                    Text(
                        dateLabel,
                        style = MaterialTheme.typography.labelLarge,
                        color = colors.onTint(accent),
                        modifier = Modifier.weight(1f)
                    )
                    FavoriteToggle(favorite = page.favorite, onClick = onToggleFavorite)
                }

                if (page.title.isNotBlank()) {
                    Spacer(Modifier.height(6.dp))
                    Text(
                        page.title,
                        style = MaterialTheme.typography.titleMedium,
                        color = colors.textPrimary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }

                if (page.body.isNotBlank()) {
                    Spacer(Modifier.height(4.dp))
                    Text(
                        page.body,
                        style = MaterialTheme.typography.bodyMedium,
                        color = colors.textSecondary,
                        maxLines = if (page.hasPhoto) 2 else 3,
                        overflow = TextOverflow.Ellipsis
                    )
                }

                if (photo != null) {
                    Spacer(Modifier.height(10.dp))
                    DiaryPhoto(
                        file = photo,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(120.dp)
                            .clip(RoundedCornerShape(14.dp))
                    )
                } else if (page.hasPhoto) {
                    // The row still says a photo exists; the file is gone.
                    Spacer(Modifier.height(8.dp))
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Icon(
                            Icons.Rounded.PhotoCamera,
                            contentDescription = null,
                            tint = colors.textSecondary,
                            modifier = Modifier.size(16.dp)
                        )
                        Text(
                            stringResource(R.string.photo_missing),
                            style = MaterialTheme.typography.labelSmall,
                            color = colors.textSecondary
                        )
                    }
                }

                if (page.tags.isNotEmpty()) {
                    Spacer(Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        page.tags.take(4).forEach { tag ->
                            Pill(text = tag, color = accent)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun FavoriteToggle(favorite: Boolean, onClick: () -> Unit) {
    val colors = DiaryTheme.colors
    Box(
        Modifier
            .size(32.dp)
            .clip(CircleShape)
            .background(if (favorite) colors.tint(colors.coral) else Color.Transparent)
            .combinedClickableCompat(onClick),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            Icons.Rounded.Favorite,
            contentDescription = stringResource(
                if (favorite) R.string.unfavorite_diary else R.string.favorite_diary
            ),
            tint = if (favorite) colors.coral else colors.textSecondary.copy(alpha = 0.5f),
            modifier = Modifier.size(18.dp)
        )
    }
}

/**
 * The card itself is already clickable, and a plain `clickable` child inside a
 * `combinedClickable` parent lets the long-press fall through to the parent.
 * Consuming both gestures here keeps a long-press on the heart from opening
 * the page behind it.
 */
@OptIn(ExperimentalFoundationApi::class)
private fun Modifier.combinedClickableCompat(onClick: () -> Unit): Modifier =
    this.combinedClickable(onClick = onClick, onLongClick = onClick)

/**
 * Decodes a diary photo straight from the private file.
 *
 * No image library is used: there is at most one photo per page and the files
 * are local, so a dependency would buy nothing and cost APK size.
 */
@Composable
fun DiaryPhoto(file: File, modifier: Modifier = Modifier) {
    val bitmap = androidx.compose.runtime.remember(file.path, file.lastModified()) {
        runCatching {
            android.graphics.BitmapFactory.decodeFile(
                file.path,
                // Diary photos are shown at card width at most; full-resolution
                // camera images would blow the bitmap budget for no visible gain.
                android.graphics.BitmapFactory.Options().apply { inSampleSize = 2 }
            )
        }.getOrNull()
    }
    if (bitmap != null) {
        Image(
            bitmap = bitmap.asImageBitmap(),
            contentDescription = stringResource(R.string.cd_diary_photo),
            contentScale = ContentScale.Crop,
            modifier = modifier
        )
    }
}
