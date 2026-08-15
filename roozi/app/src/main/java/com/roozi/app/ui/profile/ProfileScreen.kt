package com.roozi.app.ui.profile

import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
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
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.DeleteOutline
import androidx.compose.material.icons.rounded.Download
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.Restore
import androidx.compose.material.icons.rounded.Upload
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.roozi.app.R
import com.roozi.app.data.backup.BackupManager
import com.roozi.app.data.prefs.AppLanguage
import com.roozi.app.data.prefs.ThemeMode
import com.roozi.app.data.repo.Category
import com.roozi.app.data.repo.DefaultCategories
import com.roozi.app.data.repo.Task
import com.roozi.app.ui.LocalDateFormatter
import com.roozi.app.ui.MainViewModel
import com.roozi.app.ui.TasksViewModel
import com.roozi.app.ui.components.EmptyState
import com.roozi.app.ui.components.Pill
import com.roozi.app.ui.components.RooziCard
import com.roozi.app.ui.components.SectionHeader
import com.roozi.app.ui.components.SelectableChip
import com.roozi.app.ui.components.TaskCardContent
import com.roozi.app.ui.components.WeeklyBars
import com.roozi.app.ui.displayName
import com.roozi.app.ui.theme.RooziTheme
import com.roozi.app.ui.theme.ThemePalette
import com.roozi.app.ui.theme.rooziColorsOf
import kotlinx.coroutines.launch

@Composable
fun ProfileScreen(
    tasksViewModel: TasksViewModel,
    mainViewModel: MainViewModel,
    backupManager: BackupManager,
    userName: String,
    theme: ThemeMode,
    language: AppLanguage,
    palette: ThemePalette,
    contentPadding: PaddingValues,
    modifier: Modifier = Modifier
) {
    val colors = RooziTheme.colors
    val formatter = LocalDateFormatter.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val stats by tasksViewModel.stats.collectAsStateWithLifecycle()
    val completed by tasksViewModel.completed.collectAsStateWithLifecycle()
    val categories by tasksViewModel.categories.collectAsStateWithLifecycle()

    var showNameDialog by rememberSaveable { mutableStateOf(false) }
    var showCategoryDialog by rememberSaveable { mutableStateOf(false) }

    val exportLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument(BackupManager.MIME)
    ) { uri ->
        if (uri != null) scope.launch {
            val result = backupManager.export(uri)
            Toast.makeText(
                context,
                context.getString(if (result.isSuccess) R.string.backup_success else R.string.backup_failed),
                Toast.LENGTH_SHORT
            ).show()
        }
    }

    val importLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri != null) scope.launch {
            val result = backupManager.import(uri)
            Toast.makeText(
                context,
                context.getString(if (result.isSuccess) R.string.restore_success else R.string.restore_failed),
                Toast.LENGTH_SHORT
            ).show()
        }
    }

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(colors.gradientStart, colors.background))),
        contentPadding = PaddingValues(
            start = 20.dp,
            end = 20.dp,
            top = contentPadding.calculateTopPadding() + 12.dp,
            bottom = contentPadding.calculateBottomPadding() + 96.dp
        ),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item("profileHeader") {
            ProfileHeader(
                userName = userName,
                streakText = stringResource(R.string.streak_value, formatter.digits(stats.streak)),
                onEditName = { showNameDialog = true }
            )
        }

        item("stats") {
            SectionHeader(stringResource(R.string.my_stats))
        }

        item("statCards") {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatCard(
                    modifier = Modifier.weight(1f),
                    value = formatter.digits(stats.completed),
                    label = stringResource(R.string.stats_done),
                    accent = colors.mint
                )
                StatCard(
                    modifier = Modifier.weight(1f),
                    value = formatter.digits(stats.pending),
                    label = stringResource(R.string.stats_undone),
                    accent = colors.orange
                )
                StatCard(
                    modifier = Modifier.weight(1f),
                    value = formatter.percent(stats.successRate),
                    label = stringResource(R.string.stats_rate),
                    accent = colors.purple
                )
            }
        }

        item("weekly") {
            RooziCard(Modifier.fillMaxWidth()) {
                Column {
                    Text(
                        stringResource(R.string.weekly_performance),
                        style = MaterialTheme.typography.titleSmall,
                        color = colors.textPrimary
                    )
                    Spacer(Modifier.height(14.dp))
                    val max = (stats.weekly.maxOrNull() ?: 0).coerceAtLeast(1).toFloat()
                    WeeklyBars(
                        values = stats.weekly.map { it / max },
                        labels = stats.weeklyDates.map { formatter.digits(formatter.shortDate(it).takeWhile { c -> c != ' ' }) }
                    )
                }
            }
        }

        item("settings") { SectionHeader(stringResource(R.string.settings)) }

        item("theme") {
            RooziCard(Modifier.fillMaxWidth()) {
                Column {
                    Text(
                        stringResource(R.string.theme),
                        style = MaterialTheme.typography.titleSmall,
                        color = colors.textPrimary
                    )
                    Spacer(Modifier.height(10.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        ThemeMode.entries.forEach { mode ->
                            SelectableChip(
                                text = stringResource(
                                    when (mode) {
                                        ThemeMode.SYSTEM -> R.string.theme_system
                                        ThemeMode.LIGHT -> R.string.theme_light
                                        ThemeMode.DARK -> R.string.theme_dark
                                    }
                                ),
                                selected = theme == mode,
                                accent = colors.purple,
                                onClick = { mainViewModel.setTheme(mode) }
                            )
                        }
                    }
                    Spacer(Modifier.height(16.dp))
                    Text(
                        stringResource(R.string.language),
                        style = MaterialTheme.typography.titleSmall,
                        color = colors.textPrimary
                    )
                    Spacer(Modifier.height(10.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        AppLanguage.entries.forEach { lang ->
                            SelectableChip(
                                text = stringResource(
                                    if (lang == AppLanguage.PERSIAN) R.string.language_fa else R.string.language_en
                                ),
                                selected = language == lang,
                                accent = colors.turquoise,
                                onClick = { mainViewModel.setLanguage(lang) }
                            )
                        }
                    }
                }
            }
        }

        item("palette") {
            RooziCard(Modifier.fillMaxWidth()) {
                Column {
                    Text(
                        stringResource(R.string.theme_palette),
                        style = MaterialTheme.typography.titleSmall,
                        color = colors.textPrimary
                    )
                    Spacer(Modifier.height(12.dp))
                    androidx.compose.foundation.lazy.LazyRow(
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        items(ThemePalette.free) { option ->
                            PaletteSwatch(
                                option = option,
                                selected = palette == option,
                                dark = colors.isDark,
                                onClick = { mainViewModel.setPalette(option) }
                            )
                        }
                    }
                    Spacer(Modifier.height(10.dp))
                    Text(
                        stringResource(R.string.theme_premium_soon),
                        style = MaterialTheme.typography.labelSmall,
                        color = colors.textSecondary
                    )
                }
            }
        }

        item("categoriesHeader") {
            SectionHeader(
                stringResource(R.string.manage_categories),
                trailing = {
                    IconButton(onClick = { showCategoryDialog = true }) {
                        Icon(Icons.Rounded.Add, contentDescription = stringResource(R.string.new_category), tint = colors.coral)
                    }
                }
            )
        }

        item("categories") {
            RooziCard(Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    categories.forEach { category ->
                        CategoryRow(
                            category = category,
                            onDelete = { tasksViewModel.deleteCategory(category) }
                        )
                    }
                }
            }
        }

        item("backupHeader") { SectionHeader(stringResource(R.string.backup)) }

        item("backup") {
            RooziCard(Modifier.fillMaxWidth()) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    ActionTile(
                        modifier = Modifier.weight(1f),
                        icon = Icons.Rounded.Upload,
                        label = stringResource(R.string.export_backup),
                        accent = colors.mint,
                        onClick = { exportLauncher.launch(BackupManager.suggestedFileName()) }
                    )
                    ActionTile(
                        modifier = Modifier.weight(1f),
                        icon = Icons.Rounded.Download,
                        label = stringResource(R.string.import_backup),
                        accent = colors.turquoise,
                        onClick = { importLauncher.launch(arrayOf(BackupManager.MIME, "text/plain", "*/*")) }
                    )
                }
            }
        }

        item("completedHeader") {
            SectionHeader(
                stringResource(R.string.completed_tasks),
                trailing = {
                    if (completed.isNotEmpty()) {
                        TextButton(onClick = { tasksViewModel.deleteAllCompleted() }) {
                            Text(
                                stringResource(R.string.delete_all_completed),
                                style = MaterialTheme.typography.labelMedium,
                                color = colors.danger
                            )
                        }
                    }
                }
            )
        }

        if (completed.isEmpty()) {
            item("completedEmpty") {
                EmptyState(emoji = "✅", title = stringResource(R.string.empty_completed))
            }
        } else {
            items(completed.take(20), key = { it.id }) { task ->
                CompletedRow(
                    task = task,
                    onRestore = { tasksViewModel.toggleTask(task) },
                    onDelete = { tasksViewModel.deleteTask(task) }
                )
            }
        }
    }

    if (showNameDialog) {
        NameDialog(
            initial = userName,
            onDismiss = { showNameDialog = false },
            onConfirm = {
                mainViewModel.setName(it)
                showNameDialog = false
            }
        )
    }

    if (showCategoryDialog) {
        NewCategoryDialog(
            onDismiss = { showCategoryDialog = false },
            onConfirm = { name, icon, color ->
                tasksViewModel.addCategory(name, icon, color)
                showCategoryDialog = false
            }
        )
    }
}

@Composable
private fun ProfileHeader(userName: String, streakText: String, onEditName: () -> Unit) {
    val colors = RooziTheme.colors
    RooziCard(Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier
                    .size(56.dp)
                    .background(
                        Brush.linearGradient(listOf(colors.coral, colors.purple)),
                        CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = userName.trim().take(1).ifBlank { "🙂" },
                    style = MaterialTheme.typography.titleLarge,
                    color = Color.White
                )
            }
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text(
                    userName.ifBlank { stringResource(R.string.your_name) },
                    style = MaterialTheme.typography.titleMedium,
                    color = colors.textPrimary
                )
                Spacer(Modifier.height(4.dp))
                Pill(text = streakText, color = colors.orange)
            }
            IconButton(onClick = onEditName) {
                Icon(Icons.Rounded.Edit, contentDescription = stringResource(R.string.edit_name), tint = colors.textSecondary)
            }
        }
    }
}

/** Live preview chip: shows the palette's own colours, not a generic dot. */
@Composable
private fun PaletteSwatch(
    option: ThemePalette,
    selected: Boolean,
    dark: Boolean,
    onClick: () -> Unit
) {
    val colors = RooziTheme.colors
    val preview = rooziColorsOf(option, dark)
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .clickable(onClick = onClick)
            .padding(4.dp)
    ) {
        Box(
            modifier = Modifier
                .size(52.dp)
                .background(
                    Brush.linearGradient(listOf(preview.coral, preview.purple)),
                    CircleShape
                )
                .then(
                    if (selected) Modifier.border(3.dp, colors.textPrimary.copy(alpha = 0.75f), CircleShape)
                    else Modifier.border(1.dp, colors.outline, CircleShape)
                ),
            contentAlignment = Alignment.Center
        ) {
            Text(option.emoji, style = MaterialTheme.typography.titleMedium)
        }
        Spacer(Modifier.height(6.dp))
        Text(
            stringResource(option.labelRes),
            style = MaterialTheme.typography.labelSmall,
            color = if (selected) colors.textPrimary else colors.textSecondary
        )
    }
}

@Composable
private fun StatCard(value: String, label: String, accent: Color, modifier: Modifier = Modifier) {
    // Solid accent fill drawn directly: passing a translucent colour to a
    // shadowed Surface made the elevation shadow show through as a visible
    // rectangle behind the text.
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(22.dp))
            .background(
                Brush.linearGradient(listOf(accent, accent.darken(0.12f)))
            )
            .padding(vertical = 16.dp, horizontal = 12.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
            Text(
                value,
                style = MaterialTheme.typography.titleLarge.copy(shadow = statTextShadow()),
                color = Color.White
            )
            Spacer(Modifier.height(2.dp))
            Text(
                label,
                style = MaterialTheme.typography.labelSmall.copy(shadow = statTextShadow()),
                color = Color.White,
                textAlign = TextAlign.Center
            )
        }
    }
}

/** Soft drop shadow that keeps white text legible on a coloured fill. */
private fun statTextShadow() = Shadow(
    color = Color(0x59000000),
    offset = Offset(0f, 2f),
    blurRadius = 4f
)

/** Slightly darker variant of a colour, for a subtle vertical gradient. */
private fun Color.darken(amount: Float): Color = Color(
    red = red * (1f - amount),
    green = green * (1f - amount),
    blue = blue * (1f - amount),
    alpha = alpha
)

@Composable
private fun ActionTile(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    accent: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = RooziTheme.colors
    Column(
        modifier
            .background(colors.tint(accent), RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 14.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(icon, contentDescription = null, tint = colors.onTint(accent))
        Spacer(Modifier.height(6.dp))
        Text(label, style = MaterialTheme.typography.labelMedium, color = colors.textPrimary)
    }
}

@Composable
private fun CategoryRow(category: Category, onDelete: () -> Unit) {
    val colors = RooziTheme.colors
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
        Box(
            Modifier
                .size(34.dp)
                .background(colors.tint(Color(category.color)), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Text(category.icon, style = MaterialTheme.typography.bodyMedium)
        }
        Spacer(Modifier.width(10.dp))
        Text(
            category.displayName(),
            style = MaterialTheme.typography.bodyMedium,
            color = colors.textPrimary,
            modifier = Modifier.weight(1f)
        )
        if (!category.isBuiltIn) {
            IconButton(onClick = onDelete) {
                Icon(
                    Icons.Rounded.DeleteOutline,
                    contentDescription = stringResource(R.string.delete),
                    tint = colors.danger
                )
            }
        }
    }
}

@Composable
private fun CompletedRow(task: Task, onRestore: () -> Unit, onDelete: () -> Unit) {
    val colors = RooziTheme.colors
    val formatter = LocalDateFormatter.current
    RooziCard(Modifier.fillMaxWidth(), contentPadding = PaddingValues(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(
                    task.title,
                    style = MaterialTheme.typography.titleSmall,
                    color = colors.textPrimary,
                    textDecoration = androidx.compose.ui.text.style.TextDecoration.LineThrough
                )
                Text(
                    task.dueDate?.let { formatter.relativeDate(it) } ?: stringResource(R.string.no_date),
                    style = MaterialTheme.typography.labelSmall,
                    color = colors.textSecondary
                )
            }
            IconButton(onClick = onRestore) {
                Icon(Icons.Rounded.Restore, contentDescription = stringResource(R.string.restore), tint = colors.mint)
            }
            IconButton(onClick = onDelete) {
                Icon(Icons.Rounded.DeleteOutline, contentDescription = stringResource(R.string.delete), tint = colors.danger)
            }
        }
    }
}

@Composable
private fun NameDialog(initial: String, onDismiss: () -> Unit, onConfirm: (String) -> Unit) {
    var value by remember { mutableStateOf(initial) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.your_name)) },
        text = {
            OutlinedTextField(
                value = value,
                onValueChange = { value = it },
                singleLine = true,
                shape = RoundedCornerShape(14.dp),
                placeholder = { Text(stringResource(R.string.onboarding_name_hint)) }
            )
        },
        confirmButton = { TextButton(onClick = { onConfirm(value) }) { Text(stringResource(R.string.save)) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } },
        containerColor = RooziTheme.colors.surface,
        shape = RoundedCornerShape(24.dp)
    )
}

@Composable
private fun NewCategoryDialog(onDismiss: () -> Unit, onConfirm: (String, String, Int) -> Unit) {
    val colors = RooziTheme.colors
    var name by remember { mutableStateOf("") }
    var icon by remember { mutableStateOf(DefaultCategories.emojis.first()) }
    var color by remember { mutableStateOf(DefaultCategories.palette.first()) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.new_category)) },
        text = {
            Column {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    singleLine = true,
                    shape = RoundedCornerShape(14.dp),
                    label = { Text(stringResource(R.string.category_name)) }
                )
                Spacer(Modifier.height(12.dp))
                Text(stringResource(R.string.icon), style = MaterialTheme.typography.labelMedium, color = colors.textSecondary)
                Spacer(Modifier.height(6.dp))
                androidx.compose.foundation.lazy.LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    items(DefaultCategories.emojis) { emoji ->
                        Box(
                            Modifier
                                .size(38.dp)
                                .background(
                                    if (emoji == icon) colors.tint(Color(color)) else colors.surfaceMuted,
                                    CircleShape
                                )
                                .clickable { icon = emoji },
                            contentAlignment = Alignment.Center
                        ) { Text(emoji) }
                    }
                }
                Spacer(Modifier.height(12.dp))
                Text(stringResource(R.string.color), style = MaterialTheme.typography.labelMedium, color = colors.textSecondary)
                Spacer(Modifier.height(6.dp))
                androidx.compose.foundation.lazy.LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(DefaultCategories.palette) { paletteColor ->
                        Box(
                            Modifier
                                .size(32.dp)
                                .background(Color(paletteColor), CircleShape)
                                .clickable { color = paletteColor },
                            contentAlignment = Alignment.Center
                        ) {
                            if (paletteColor == color) {
                                Box(
                                    Modifier
                                        .size(12.dp)
                                        .background(Color.White, CircleShape)
                                )
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = { if (name.isNotBlank()) onConfirm(name, icon, color) },
                enabled = name.isNotBlank()
            ) { Text(stringResource(R.string.add)) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } },
        containerColor = colors.surface,
        shape = RoundedCornerShape(24.dp)
    )
}
