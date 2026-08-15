package com.roozi.app.ui.onboarding

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.roozi.app.R
import com.roozi.app.ui.theme.RooziTheme

private data class Page(val emoji: String, val titleRes: Int, val descRes: Int)

/** Which step of the onboarding flow is showing. */
private data class Step(val naming: Boolean, val page: Int)

private val pages = listOf(
    Page("✨", R.string.onboarding_title_1, R.string.onboarding_desc_1),
    Page("🗓️", R.string.onboarding_title_2, R.string.onboarding_desc_2),
    Page("📈", R.string.onboarding_title_3, R.string.onboarding_desc_3)
)

@Composable
fun OnboardingScreen(
    onFinish: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = RooziTheme.colors
    var index by rememberSaveable { mutableIntStateOf(0) }
    var askName by rememberSaveable { mutableStateOf(false) }
    var name by rememberSaveable { mutableStateOf("") }

    Column(
        modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(colors.gradientStart, colors.background)))
            .systemBarsPadding()
            .imePadding()
            .padding(24.dp)
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            if (!askName) {
                TextButton(onClick = { askName = true }) {
                    Text(stringResource(R.string.onboarding_skip), color = colors.textSecondary)
                }
            }
        }

        Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
            AnimatedContent(
                targetState = Step(askName, index),
                transitionSpec = {
                    (slideInHorizontally { it / 4 } + fadeIn(tween(250))) togetherWith
                        (slideOutHorizontally { -it / 4 } + fadeOut(tween(180)))
                },
                label = "onboarding"
            ) { step ->
                if (step.naming) {
                    NameStep(
                        name = name,
                        onNameChange = { name = it },
                        onSubmit = { onFinish(name) }
                    )
                } else {
                    PageContent(pages[step.page])
                }
            }
        }

        if (!askName) {
            Row(
                Modifier.fillMaxWidth().padding(bottom = 16.dp),
                horizontalArrangement = Arrangement.Center
            ) {
                pages.indices.forEach { i ->
                    Box(
                        Modifier
                            .padding(horizontal = 3.dp)
                            .size(width = if (i == index) 22.dp else 8.dp, height = 8.dp)
                            .background(
                                if (i == index) colors.coral else colors.textSecondary.copy(alpha = 0.3f),
                                CircleShape
                            )
                    )
                }
            }
            Button(
                onClick = { if (index < pages.lastIndex) index++ else askName = true },
                modifier = Modifier.fillMaxWidth().height(54.dp),
                shape = RoundedCornerShape(18.dp),
                colors = ButtonDefaults.buttonColors(containerColor = colors.coral, contentColor = Color.White)
            ) {
                Text(
                    stringResource(if (index < pages.lastIndex) R.string.onboarding_next else R.string.onboarding_start),
                    style = MaterialTheme.typography.labelLarge
                )
            }
        }
    }
}

@Composable
private fun PageContent(page: Page) {
    val colors = RooziTheme.colors
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.fillMaxWidth()
    ) {
        Box(
            Modifier
                .size(120.dp)
                .background(
                    Brush.linearGradient(listOf(colors.tint(colors.coral), colors.tint(colors.purple))),
                    CircleShape
                ),
            contentAlignment = Alignment.Center
        ) {
            Text(page.emoji, style = MaterialTheme.typography.displaySmall)
        }
        Spacer(Modifier.height(28.dp))
        Text(
            stringResource(page.titleRes),
            style = MaterialTheme.typography.headlineSmall,
            color = colors.textPrimary,
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(10.dp))
        Text(
            stringResource(page.descRes),
            style = MaterialTheme.typography.bodyMedium,
            color = colors.textSecondary,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun NameStep(name: String, onNameChange: (String) -> Unit, onSubmit: () -> Unit) {
    val colors = RooziTheme.colors
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.fillMaxWidth()
    ) {
        Text("👋", style = MaterialTheme.typography.displaySmall)
        Spacer(Modifier.height(16.dp))
        Text(
            stringResource(R.string.onboarding_name_question),
            style = MaterialTheme.typography.titleMedium,
            color = colors.textPrimary,
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(18.dp))
        OutlinedTextField(
            value = name,
            onValueChange = onNameChange,
            modifier = Modifier.fillMaxWidth(),
            placeholder = { Text(stringResource(R.string.onboarding_name_hint)) },
            singleLine = true,
            shape = RoundedCornerShape(16.dp),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { onSubmit() }),
            colors = TextFieldDefaults.colors(
                focusedContainerColor = colors.surface,
                unfocusedContainerColor = colors.surface,
                focusedIndicatorColor = colors.coral,
                unfocusedIndicatorColor = Color.Transparent,
                cursorColor = colors.coral
            )
        )
        Spacer(Modifier.height(20.dp))
        Button(
            onClick = onSubmit,
            modifier = Modifier.fillMaxWidth().height(54.dp),
            shape = RoundedCornerShape(18.dp),
            colors = ButtonDefaults.buttonColors(containerColor = colors.coral, contentColor = Color.White)
        ) {
            Text(stringResource(R.string.onboarding_continue), style = MaterialTheme.typography.labelLarge)
        }
        Spacer(Modifier.width(4.dp))
    }
}
