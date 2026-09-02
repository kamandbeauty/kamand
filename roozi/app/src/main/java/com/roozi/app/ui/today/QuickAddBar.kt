package com.roozi.app.ui.today

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.speech.RecognizerIntent
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Mic
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import com.roozi.app.R
import com.roozi.app.ui.theme.RooziTheme
import java.util.Locale

/**
 * One-line capture on the Today screen: type (or dictate) a title and save.
 *
 * Deliberately has no date/time/reminder controls — that is the whole point.
 * Details can be added later by tapping the task.
 */
@Composable
fun QuickAddBar(
    persian: Boolean,
    onAdd: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = RooziTheme.colors
    val context = LocalContext.current
    val keyboard = LocalSoftwareKeyboardController.current
    var text by rememberSaveable { mutableStateOf("") }

    val canSave = text.isNotBlank()
    val addTint by animateColorAsState(
        if (canSave) colors.coral else colors.textSecondary.copy(alpha = 0.45f),
        label = "quickAddTint"
    )

    fun submit() {
        if (text.isNotBlank()) {
            onAdd(text.trim())
            text = ""
            keyboard?.hide()
        }
    }

    // Speech recognition is optional: if the device has no recognizer we simply
    // tell the user instead of crashing.
    val voiceLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val spoken = result.data
                ?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                ?.firstOrNull()
                .orEmpty()
            if (spoken.isNotBlank()) {
                text = if (text.isBlank()) spoken else "$text $spoken"
            }
        }
    }

    val voicePrompt = stringResource(R.string.voice_prompt)
    val unavailable = stringResource(R.string.voice_unavailable)

    Surface(
        modifier = modifier.fillMaxWidth(),
        color = colors.surface,
        shape = RoundedCornerShape(20.dp),
        shadowElevation = if (colors.isDark) 0.dp else 3.dp,
        border = if (colors.isDark)
            androidx.compose.foundation.BorderStroke(1.dp, colors.outline) else null
    ) {
        Row(
            modifier = Modifier.padding(start = 6.dp, end = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            IconButton(
                onClick = {
                    val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                        putExtra(
                            RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                            RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
                        )
                        putExtra(
                            RecognizerIntent.EXTRA_LANGUAGE,
                            if (persian) "fa-IR" else Locale.getDefault().toLanguageTag()
                        )
                        putExtra(RecognizerIntent.EXTRA_PROMPT, voicePrompt)
                    }
                    try {
                        voiceLauncher.launch(intent)
                    } catch (e: ActivityNotFoundException) {
                        Toast.makeText(context, unavailable, Toast.LENGTH_SHORT).show()
                    }
                },
                modifier = Modifier.size(44.dp)
            ) {
                Icon(
                    Icons.Rounded.Mic,
                    contentDescription = stringResource(R.string.voice_input),
                    tint = colors.textSecondary
                )
            }

            TextField(
                value = text,
                onValueChange = { text = it },
                modifier = Modifier.weight(1f),
                placeholder = {
                    Text(
                        stringResource(R.string.quick_add_hint),
                        style = MaterialTheme.typography.bodyMedium
                    )
                },
                singleLine = true,
                textStyle = MaterialTheme.typography.bodyMedium,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = { submit() }),
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = Color.Transparent,
                    unfocusedContainerColor = Color.Transparent,
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent,
                    cursorColor = colors.coral,
                    focusedTextColor = colors.textPrimary,
                    unfocusedTextColor = colors.textPrimary
                )
            )

            IconButton(
                onClick = ::submit,
                enabled = canSave,
                modifier = Modifier.size(44.dp)
            ) {
                Icon(
                    Icons.Rounded.Add,
                    contentDescription = stringResource(R.string.quick_add),
                    tint = addTint
                )
            }
        }
    }
    Spacer(Modifier.width(0.dp))
}
