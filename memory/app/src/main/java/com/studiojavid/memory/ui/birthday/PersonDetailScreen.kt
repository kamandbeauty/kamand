package com.studiojavid.memory.ui.birthday

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.widget.Toast
import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.DeleteOutline
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.Share
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextFieldDefaults
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
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.studiojavid.memory.R
import com.studiojavid.memory.data.repo.BirthdayMessages
import com.studiojavid.memory.data.repo.BirthdayPerson
import com.studiojavid.memory.data.repo.GiftIdea
import com.studiojavid.memory.ui.BirthdayViewModel
import com.studiojavid.memory.ui.LocalDateFormatter
import com.studiojavid.memory.ui.components.MemoryCard
import com.studiojavid.memory.ui.components.SectionHeader
import com.studiojavid.memory.ui.components.accentTextShadow
import com.studiojavid.memory.ui.theme.MemoryTheme

/**
 * Everything about one person: countdown, notes, gift ideas and the greeting
 * they should get. Gift ideas can become real tasks, which is the bridge back
 * into the rest of the app.
 */
@Composable
fun PersonDetailScreen(
    viewModel: BirthdayViewModel,
    person: BirthdayPerson,
    onBack: () -> Unit,
    onEdit: () -> Unit,
    onPickMessage: () -> Unit,
    contentPadding: PaddingValues,
    modifier: Modifier = Modifier
) {
    val colors = MemoryTheme.colors
    val formatter = LocalDateFormatter.current
    val context = LocalContext.current
    val ideas by viewModel.giftIdeas.collectAsStateWithLifecycle()
    var newIdea by remember { mutableStateOf("") }

    val favorite = remember(person.favoriteMessageId) {
        BirthdayMessages.byId(person.favoriteMessageId)
    }
    val favoriteText = favorite?.let {
        rememberPersonalized(stringResource(it.textRes), person.name)
    }

    val noteCreated = stringResource(R.string.gift_note_created)

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
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item("hero") {
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onBack) {
                    Icon(
                        Icons.AutoMirrored.Rounded.ArrowBack,
                        contentDescription = stringResource(R.string.cd_back),
                        tint = colors.textSecondary
                    )
                }
                Spacer(Modifier.weight(1f))
                IconButton(onClick = onEdit) {
                    Icon(
                        Icons.Rounded.Edit,
                        contentDescription = stringResource(R.string.edit_birthday),
                        tint = colors.textSecondary
                    )
                }
            }

            Box(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(26.dp))
                    .background(Brush.linearGradient(listOf(colors.coral, colors.purple)))
                    .padding(20.dp)
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                    Box(
                        Modifier
                            .size(72.dp)
                            .clip(CircleShape)
                            .background(Color.White.copy(alpha = 0.25f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(person.displayAvatar, style = MaterialTheme.typography.headlineMedium)
                    }
                    Spacer(Modifier.height(10.dp))
                    Text(
                        person.name,
                        style = MaterialTheme.typography.headlineSmall.copy(shadow = accentTextShadow()),
                        color = Color.White
                    )
                    if (person.relationship.isNotBlank()) {
                        Text(
                            person.relationship,
                            style = MaterialTheme.typography.labelMedium.copy(shadow = accentTextShadow()),
                            color = Color.White.copy(alpha = 0.9f)
                        )
                    }
                    Spacer(Modifier.height(8.dp))
                    Text(
                        // Full date when the year is known, day/month otherwise.
                        person.birthYear?.let {
                            formatter.jalaliFull(it, person.birthMonth, person.birthDay)
                        } ?: formatter.jalaliDayMonth(person.birthMonth, person.birthDay),
                        style = MaterialTheme.typography.titleMedium.copy(shadow = accentTextShadow()),
                        color = Color.White
                    )
                    Spacer(Modifier.height(6.dp))
                    Text(
                        when {
                            person.isToday -> stringResource(R.string.birthday_today_full)
                            person.isTomorrow -> stringResource(R.string.birthday_tomorrow)
                            else -> stringResource(
                                R.string.birthday_in_days,
                                formatter.digits(person.daysUntil)
                            )
                        },
                        style = MaterialTheme.typography.titleSmall.copy(shadow = accentTextShadow()),
                        color = Color.White
                    )
                    person.turningAge?.let { age ->
                        Text(
                            stringResource(R.string.turns_age, formatter.digits(age)),
                            style = MaterialTheme.typography.labelMedium.copy(shadow = accentTextShadow()),
                            color = Color.White.copy(alpha = 0.9f)
                        )
                    }
                }
            }
        }

        if (person.notes.isNotBlank()) {
            item("notesHeader") { SectionHeader("📝 " + stringResource(R.string.person_notes)) }
            item("notes") {
                MemoryCard(Modifier.fillMaxWidth()) {
                    Text(
                        person.notes,
                        style = MaterialTheme.typography.bodyMedium,
                        color = colors.textPrimary
                    )
                }
            }
        }

        item("giftHeader") { SectionHeader("🎁 " + stringResource(R.string.gift_ideas)) }

        item("giftInput") {
            MemoryCard(Modifier.fillMaxWidth(), contentPadding = PaddingValues(8.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    OutlinedTextField(
                        value = newIdea,
                        onValueChange = { newIdea = it },
                        modifier = Modifier.weight(1f),
                        placeholder = { Text(stringResource(R.string.gift_idea_hint)) },
                        singleLine = true,
                        shape = RoundedCornerShape(14.dp),
                        colors = TextFieldDefaults.colors(
                            focusedContainerColor = colors.surfaceMuted,
                            unfocusedContainerColor = colors.surfaceMuted,
                            focusedIndicatorColor = Color.Transparent,
                            unfocusedIndicatorColor = Color.Transparent,
                            cursorColor = colors.coral
                        )
                    )
                    IconButton(
                        onClick = {
                            viewModel.addGiftIdea(person.id, newIdea)
                            newIdea = ""
                        },
                        enabled = newIdea.isNotBlank()
                    ) {
                        Icon(
                            Icons.Rounded.Add,
                            contentDescription = stringResource(R.string.add_gift_idea),
                            tint = if (newIdea.isNotBlank()) colors.coral
                            else colors.textSecondary.copy(alpha = 0.4f)
                        )
                    }
                }
            }
        }

        items(ideas, key = { it.id }) { idea ->
            GiftIdeaRow(
                idea = idea,
                onToggle = { viewModel.toggleGiftIdea(idea) },
                onDelete = { viewModel.deleteGiftIdea(idea) },
                onConvert = {
                    val title = context.getString(R.string.gift_note_title, idea.title, person.name)
                    val body = context.getString(
                        R.string.gift_note_body,
                        person.name,
                        formatter.jalaliDayMonth(person.birthMonth, person.birthDay)
                    )
                    viewModel.giftIdeaToNote(title, body)
                    Toast.makeText(context, noteCreated, Toast.LENGTH_SHORT).show()
                }
            )
        }

        item("messageHeader") { SectionHeader("💌 " + stringResource(R.string.greeting_messages)) }

        item("message") {
            MemoryCard(
                Modifier
                    .fillMaxWidth()
                    .clickable(onClick = onPickMessage)
            ) {
                Column {
                    if (favoriteText != null) {
                        Text(
                            favoriteText,
                            style = MaterialTheme.typography.bodyMedium,
                            color = colors.textPrimary
                        )
                        Spacer(Modifier.height(12.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            MessageAction(
                                icon = Icons.Rounded.ContentCopy,
                                label = stringResource(R.string.copy_message),
                                accent = colors.mint,
                                modifier = Modifier.weight(1f)
                            ) { copyToClipboard(context, favoriteText) }
                            MessageAction(
                                icon = Icons.Rounded.Share,
                                label = stringResource(R.string.share_message),
                                accent = colors.turquoise,
                                modifier = Modifier.weight(1f)
                            ) { shareText(context, favoriteText) }
                        }
                    } else {
                        Text(
                            stringResource(R.string.pick_message),
                            style = MaterialTheme.typography.bodyMedium,
                            color = colors.textSecondary
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun GiftIdeaRow(
    idea: GiftIdea,
    onToggle: () -> Unit,
    onDelete: () -> Unit,
    onConvert: () -> Unit
) {
    val colors = MemoryTheme.colors
    MemoryCard(Modifier.fillMaxWidth(), contentPadding = PaddingValues(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier
                    .size(40.dp)
                    .clickable(onClick = onToggle),
                contentAlignment = Alignment.Center
            ) {
                Box(
                    Modifier
                        .size(22.dp)
                        .clip(CircleShape)
                        .background(
                            if (idea.isCompleted) colors.mint
                            else colors.textSecondary.copy(alpha = 0.18f)
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    if (idea.isCompleted) {
                        Icon(
                            Icons.Rounded.Check,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(14.dp)
                        )
                    }
                }
            }
            Text(
                idea.title,
                style = MaterialTheme.typography.bodyMedium,
                color = if (idea.isCompleted) colors.textSecondary else colors.textPrimary,
                textDecoration = if (idea.isCompleted) TextDecoration.LineThrough else null,
                modifier = Modifier.weight(1f)
            )
            Box(
                Modifier
                    .clip(CircleShape)
                    .background(colors.tint(colors.purple))
                    .clickable(onClick = onConvert)
                    .padding(horizontal = 10.dp, vertical = 6.dp)
            ) {
                Text(
                    stringResource(R.string.convert_to_task),
                    style = MaterialTheme.typography.labelSmall,
                    color = colors.onTint(colors.purple)
                )
            }
            IconButton(onClick = onDelete, modifier = Modifier.size(40.dp)) {
                Icon(
                    Icons.Rounded.DeleteOutline,
                    contentDescription = stringResource(R.string.delete),
                    tint = colors.danger,
                    modifier = Modifier.size(18.dp)
                )
            }
        }
    }
}

@Composable
private fun MessageAction(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    accent: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    val colors = MemoryTheme.colors
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

internal fun copyToClipboard(context: Context, text: String) {
    val manager = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
    manager?.setPrimaryClip(ClipData.newPlainText("MEMORY", text))
    Toast.makeText(context, context.getString(R.string.message_copied), Toast.LENGTH_SHORT).show()
}

/** Uses the system share sheet: no dependency on any specific messenger. */
internal fun shareText(context: Context, text: String) {
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, text)
    }
    runCatching {
        context.startActivity(
            Intent.createChooser(intent, context.getString(R.string.share_message))
        )
    }
}
