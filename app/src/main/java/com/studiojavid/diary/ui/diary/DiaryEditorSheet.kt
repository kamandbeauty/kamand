package com.studiojavid.diary.ui.diary

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AddPhotoAlternate
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SheetState
import androidx.compose.material3.Text
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.studiojavid.diary.R
import com.studiojavid.diary.core.date.DateFormatter
import com.studiojavid.diary.data.local.Mood
import com.studiojavid.diary.data.repo.DiaryPage
import com.studiojavid.diary.ui.components.DiaryPhoto
import com.studiojavid.diary.ui.components.MoodPicker
import com.studiojavid.diary.ui.components.SelectableChip
import com.studiojavid.diary.ui.theme.DiaryTheme
import java.io.File
import java.time.LocalDate

/** What the editor hands back on save. */
data class DiaryDraft(
    val date: LocalDate,
    val title: String,
    val body: String,
    val mood: Mood,
    val tags: List<String>,
    val photo: String,
    val favorite: Boolean
)

/** Suggested tags. Emoji, so they read the same in both locales. */
private val tagSuggestions = listOf("👨‍👩‍👧", "💼", "✈️", "🎉", "❤️", "🏃", "📚", "🍽️")

/**
 * The diary page editor.
 *
 * Writing is the only required act: mood, tags and the photo sit below the
 * text and never gate the save button.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DiaryEditorSheet(
    sheetState: SheetState,
    date: LocalDate,
    formatter: DateFormatter,
    editing: DiaryPage?,
    photoFile: (String) -> File?,
    onPickPhoto: (Uri, (String?) -> Unit) -> Unit,
    onDelete: (() -> Unit)?,
    onDismiss: () -> Unit,
    onSave: (DiaryDraft) -> Unit
) {
    val colors = DiaryTheme.colors

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = colors.surface,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
        dragHandle = {
            Box(
                Modifier.fillMaxWidth().padding(top = 12.dp, bottom = 4.dp),
                contentAlignment = Alignment.Center
            ) {
                Box(
                    Modifier
                        .size(width = 42.dp, height = 5.dp)
                        .background(
                            colors.textSecondary.copy(alpha = 0.3f),
                            RoundedCornerShape(3.dp)
                        )
                )
            }
        }
    ) {
        DiaryEditorContent(
            date = date,
            formatter = formatter,
            editing = editing,
            photoFile = photoFile,
            onPickPhoto = onPickPhoto,
            onDelete = onDelete,
            onSave = onSave
        )
    }
}

@Composable
private fun DiaryEditorContent(
    date: LocalDate,
    formatter: DateFormatter,
    editing: DiaryPage?,
    photoFile: (String) -> File?,
    onPickPhoto: (Uri, (String?) -> Unit) -> Unit,
    onDelete: (() -> Unit)?,
    onSave: (DiaryDraft) -> Unit
) {
    val colors = DiaryTheme.colors
    val keyboard = LocalSoftwareKeyboardController.current

    // Keyed on the page id so reopening a different day resets the draft
    // instead of carrying the previous day's text over.
    val key = editing?.id ?: date.toEpochDay()
    var title by rememberSaveable(key) { mutableStateOf(editing?.title ?: "") }
    var body by rememberSaveable(key) { mutableStateOf(editing?.body ?: "") }
    var mood by rememberSaveable(key) { mutableStateOf(editing?.mood ?: Mood.UNSET) }
    var tags by rememberSaveable(key) { mutableStateOf(editing?.tags ?: emptyList()) }
    var photo by rememberSaveable(key) { mutableStateOf(editing?.photo ?: "") }
    var favorite by rememberSaveable(key) { mutableStateOf(editing?.favorite ?: false) }

    // Photo Picker rather than READ_MEDIA_IMAGES: it needs no permission at
    // all and grants access to exactly the one image the user chose.
    val picker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri: Uri? ->
        if (uri != null) onPickPhoto(uri) { stored -> if (stored != null) photo = stored }
    }

    val focusRequester = remember { FocusRequester() }
    LaunchedEffect(key) {
        if (editing == null) {
            kotlinx.coroutines.delay(120)
            runCatching { focusRequester.requestFocus() }
        }
    }

    val canSave = title.isNotBlank() || body.isNotBlank() || photo.isNotEmpty()

    Column(
        Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .imePadding()
            .navigationBarsPadding()
            .padding(horizontal = 20.dp)
            .padding(bottom = 20.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(
                    stringResource(
                        if (editing == null) R.string.new_diary else R.string.edit_diary
                    ),
                    style = MaterialTheme.typography.titleMedium,
                    color = colors.textPrimary
                )
                Text(
                    formatter.weekdayAndDate(date),
                    style = MaterialTheme.typography.bodySmall,
                    color = colors.textSecondary
                )
            }
            IconToggle(
                selected = favorite,
                accent = colors.coral,
                icon = Icons.Rounded.Favorite,
                description = stringResource(
                    if (favorite) R.string.unfavorite_diary else R.string.favorite_diary
                ),
                onClick = { favorite = !favorite }
            )
            if (onDelete != null) {
                Spacer(Modifier.size(4.dp))
                IconToggle(
                    selected = false,
                    accent = colors.coral,
                    icon = Icons.Rounded.Delete,
                    description = stringResource(R.string.delete_diary),
                    onClick = onDelete
                )
            }
        }

        Spacer(Modifier.height(14.dp))
        FieldLabel(stringResource(R.string.mood_question))
        MoodPicker(selected = mood, onSelect = { mood = it })

        Spacer(Modifier.height(14.dp))
        OutlinedTextField(
            value = title,
            onValueChange = { title = it },
            modifier = Modifier.fillMaxWidth(),
            placeholder = { Text(stringResource(R.string.diary_title_hint)) },
            label = { Text(stringResource(R.string.diary_title)) },
            singleLine = true,
            shape = RoundedCornerShape(16.dp),
            colors = fieldColors()
        )

        Spacer(Modifier.height(10.dp))
        OutlinedTextField(
            value = body,
            onValueChange = { body = it },
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 170.dp)
                .focusRequester(focusRequester),
            placeholder = { Text(stringResource(R.string.diary_body_hint)) },
            label = { Text(stringResource(R.string.diary_body)) },
            shape = RoundedCornerShape(16.dp),
            colors = fieldColors()
        )

        Spacer(Modifier.height(16.dp))
        FieldLabel(stringResource(R.string.diary_tags))
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(tagSuggestions.size) { index ->
                val tag = tagSuggestions[index]
                SelectableChip(
                    text = tag,
                    selected = tag in tags,
                    accent = colors.purple,
                    onClick = {
                        tags = if (tag in tags) tags - tag else tags + tag
                    }
                )
            }
        }

        Spacer(Modifier.height(16.dp))
        FieldLabel(stringResource(R.string.diary_photo))
        val file = photo.takeIf { it.isNotEmpty() }?.let(photoFile)
        if (file != null) {
            Box(Modifier.fillMaxWidth()) {
                DiaryPhoto(
                    file = file,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(180.dp)
                        .clip(RoundedCornerShape(16.dp))
                )
                Box(
                    Modifier
                        .align(Alignment.TopEnd)
                        .padding(8.dp)
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(colors.surface.copy(alpha = 0.85f))
                        .clickable { photo = "" },
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Rounded.Close,
                        contentDescription = stringResource(R.string.remove_photo),
                        tint = colors.textPrimary,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
        } else {
            Row(
                Modifier
                    .fillMaxWidth()
                    .height(56.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(colors.surfaceMuted)
                    .clickable {
                        picker.launch(
                            PickVisualMediaRequest(
                                ActivityResultContracts.PickVisualMedia.ImageOnly
                            )
                        )
                    }
                    .padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Icon(
                    Icons.Rounded.AddPhotoAlternate,
                    contentDescription = null,
                    tint = colors.purple
                )
                Text(
                    stringResource(R.string.add_photo),
                    style = MaterialTheme.typography.bodyMedium,
                    color = colors.textSecondary
                )
            }
        }

        Spacer(Modifier.height(20.dp))
        Button(
            onClick = {
                keyboard?.hide()
                onSave(
                    DiaryDraft(
                        date = date,
                        title = title,
                        body = body,
                        mood = mood,
                        tags = tags,
                        photo = photo,
                        favorite = favorite
                    )
                )
            },
            enabled = canSave,
            modifier = Modifier.fillMaxWidth().height(54.dp),
            shape = RoundedCornerShape(18.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = colors.coral,
                contentColor = Color.White
            )
        ) {
            Text(
                stringResource(R.string.diary_save),
                style = MaterialTheme.typography.labelLarge
            )
        }
    }
}

@Composable
private fun IconToggle(
    selected: Boolean,
    accent: Color,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    description: String,
    onClick: () -> Unit
) {
    val colors = DiaryTheme.colors
    Box(
        Modifier
            .size(40.dp)
            .clip(CircleShape)
            .background(if (selected) colors.tint(accent) else Color.Transparent)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            icon,
            contentDescription = description,
            tint = if (selected) accent else colors.textSecondary,
            modifier = Modifier.size(20.dp)
        )
    }
}

@Composable
private fun FieldLabel(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.labelMedium,
        color = DiaryTheme.colors.textSecondary,
        modifier = Modifier.padding(bottom = 6.dp)
    )
}

@Composable
private fun fieldColors() = TextFieldDefaults.colors(
    focusedContainerColor = DiaryTheme.colors.surfaceMuted,
    unfocusedContainerColor = DiaryTheme.colors.surfaceMuted,
    disabledContainerColor = DiaryTheme.colors.surfaceMuted,
    focusedIndicatorColor = DiaryTheme.colors.coral,
    unfocusedIndicatorColor = Color.Transparent,
    cursorColor = DiaryTheme.colors.coral,
    focusedLabelColor = DiaryTheme.colors.coral,
    unfocusedLabelColor = DiaryTheme.colors.textSecondary
)
