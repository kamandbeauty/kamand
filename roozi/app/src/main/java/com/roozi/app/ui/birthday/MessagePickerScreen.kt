package com.roozi.app.ui.birthday

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.Share
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.roozi.app.R
import com.roozi.app.data.repo.BirthdayMessages
import com.roozi.app.data.repo.MessageCategory
import com.roozi.app.ui.components.accentTextShadow
import com.roozi.app.ui.theme.RooziTheme

/**
 * Greeting picker.
 *
 * Messages are personalised with the person's name before they are shown, so
 * what the user previews is exactly what gets copied or shared.
 */
@Composable
fun MessagePickerScreen(
    personName: String?,
    selectedMessageId: Int,
    onBack: () -> Unit,
    onUseMessage: (Int) -> Unit,
    contentPadding: PaddingValues,
    modifier: Modifier = Modifier
) {
    val colors = RooziTheme.colors
    val context = LocalContext.current
    var category by remember { mutableStateOf(MessageCategory.WARM) }
    var expandedId by remember { mutableStateOf(selectedMessageId) }

    val messages = remember(category) { BirthdayMessages.inCategory(category) }
    val savedToast = stringResource(R.string.message_saved)

    val statusBar = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(listOf(colors.tint(colors.pink), colors.background))
            ),
        contentPadding = PaddingValues(
            start = 20.dp,
            end = 20.dp,
            // The app header is hidden on this route, so the scaffold's top
            // inset collapses; the status bar must be cleared here instead.
            top = contentPadding.calculateTopPadding() + statusBar + 8.dp,
            bottom = contentPadding.calculateBottomPadding() + 96.dp
        ),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        item("header") {
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onBack) {
                    Icon(
                        Icons.AutoMirrored.Rounded.ArrowBack,
                        contentDescription = stringResource(R.string.cd_back),
                        tint = colors.textSecondary
                    )
                }
                Text(
                    "💌 " + stringResource(R.string.greeting_messages),
                    style = MaterialTheme.typography.titleLarge,
                    color = colors.textPrimary
                )
            }
        }

        item("categories") {
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(MessageCategory.entries.size) { index ->
                    val option = MessageCategory.entries[index]
                    val selected = option == category
                    val bg by animateColorAsState(
                        if (selected) colors.coral else colors.surfaceMuted,
                        label = "catBg"
                    )
                    Box(
                        Modifier
                            .clip(CircleShape)
                            .background(bg)
                            .clickable { category = option }
                            .padding(horizontal = 14.dp, vertical = 9.dp)
                    ) {
                        Text(
                            "${option.emoji} ${stringResource(option.labelRes)}",
                            style = MaterialTheme.typography.labelLarge,
                            color = if (selected) Color.White else colors.textSecondary
                        )
                    }
                }
            }
        }

        items(messages, key = { it.id }) { message ->
            val text = rememberPersonalized(stringResource(message.textRes), personName)
            val isSelected = message.id == selectedMessageId
            val isExpanded = message.id == expandedId

            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(20.dp))
                    .background(colors.surface)
                    .then(
                        if (isSelected) Modifier.border(2.dp, colors.coral, RoundedCornerShape(20.dp))
                        else Modifier
                    )
                    .clickable { expandedId = if (isExpanded) 0 else message.id }
                    .padding(14.dp)
            ) {
                Row(verticalAlignment = Alignment.Top) {
                    Text(
                        text,
                        style = MaterialTheme.typography.bodyMedium,
                        color = colors.textPrimary,
                        modifier = Modifier.weight(1f)
                    )
                    if (isSelected) {
                        Spacer(Modifier.width(8.dp))
                        Box(
                            Modifier
                                .size(22.dp)
                                .clip(CircleShape)
                                .background(colors.coral),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                Icons.Rounded.Check,
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(14.dp)
                            )
                        }
                    }
                }

                if (isExpanded) {
                    Spacer(Modifier.height(12.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Action(
                            icon = Icons.Rounded.ContentCopy,
                            label = stringResource(R.string.copy_message),
                            accent = colors.mint,
                            modifier = Modifier.weight(1f)
                        ) { copyToClipboard(context, text) }
                        Action(
                            icon = Icons.Rounded.Share,
                            label = stringResource(R.string.share_message),
                            accent = colors.turquoise,
                            modifier = Modifier.weight(1f)
                        ) { shareText(context, text) }
                    }
                    Spacer(Modifier.height(8.dp))
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(14.dp))
                            .background(
                                Brush.linearGradient(listOf(colors.coral, colors.purple))
                            )
                            .clickable {
                                onUseMessage(message.id)
                                android.widget.Toast
                                    .makeText(context, savedToast, android.widget.Toast.LENGTH_SHORT)
                                    .show()
                            }
                            .padding(vertical = 11.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            stringResource(R.string.use_for_person),
                            style = MaterialTheme.typography.labelLarge.copy(shadow = accentTextShadow()),
                            color = Color.White
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun Action(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    accent: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    val colors = RooziTheme.colors
    Row(
        modifier
            .clip(RoundedCornerShape(14.dp))
            .background(colors.tint(accent))
            .clickable(onClick = onClick)
            .padding(vertical = 10.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(icon, contentDescription = null, tint = colors.onTint(accent), modifier = Modifier.size(16.dp))
        Spacer(Modifier.width(6.dp))
        Text(label, style = MaterialTheme.typography.labelMedium, color = colors.textPrimary)
    }
}
