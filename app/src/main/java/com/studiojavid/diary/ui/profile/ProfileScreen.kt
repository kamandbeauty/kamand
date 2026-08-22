package com.studiojavid.diary.ui.profile

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
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.NotificationsActive
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.Upload
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.studiojavid.diary.MainActivity
import com.studiojavid.diary.notifications.Notifications
import com.studiojavid.diary.notifications.BirthdayScheduler
import com.studiojavid.diary.R
import com.studiojavid.diary.data.backup.BackupManager
import com.studiojavid.diary.data.prefs.AppLanguage
import com.studiojavid.diary.data.prefs.ThemeMode
import com.studiojavid.diary.data.local.Mood
import com.studiojavid.diary.ui.LocalDateFormatter
import com.studiojavid.diary.ui.MainViewModel
import com.studiojavid.diary.ui.DiaryViewModel
import com.studiojavid.diary.ui.components.Pill
import com.studiojavid.diary.ui.components.AccentCard
import com.studiojavid.diary.ui.components.accentTextShadow
import com.studiojavid.diary.ui.components.darken
import com.studiojavid.diary.ui.components.DiaryCard
import com.studiojavid.diary.ui.components.SectionHeader
import com.studiojavid.diary.ui.components.SelectableChip
import com.studiojavid.diary.ui.components.color
import com.studiojavid.diary.ui.components.emoji
import com.studiojavid.diary.ui.components.label
import com.studiojavid.diary.ui.components.selectableMoods
import com.studiojavid.diary.ui.components.WeeklyBars
import com.studiojavid.diary.ui.theme.DiaryTheme
import com.studiojavid.diary.ui.theme.ThemePalette
import com.studiojavid.diary.ui.theme.diaryColorsOf
import kotlinx.coroutines.launch

@Composable
fun ProfileScreen(
    diaryViewModel: DiaryViewModel,
    mainViewModel: MainViewModel,
    backupManager: BackupManager,
    userName: String,
    theme: ThemeMode,
    language: AppLanguage,
    palette: ThemePalette,
    lockMode: com.studiojavid.diary.ui.lock.LockMode,
    lockImmediate: Boolean,
    contentPadding: PaddingValues,
    modifier: Modifier = Modifier
) {
    val colors = DiaryTheme.colors
    val formatter = LocalDateFormatter.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val stats by diaryViewModel.stats.collectAsStateWithLifecycle()

    var showNameDialog by rememberSaveable { mutableStateOf(false) }

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
                    value = formatter.digits(stats.total),
                    label = stringResource(R.string.stats_pages),
                    accent = colors.mint
                )
                StatCard(
                    modifier = Modifier.weight(1f),
                    value = formatter.digits(stats.thisMonth),
                    label = stringResource(R.string.stats_this_month),
                    accent = colors.orange
                )
                StatCard(
                    modifier = Modifier.weight(1f),
                    value = formatter.digits(stats.favorites),
                    label = stringResource(R.string.stats_favorites),
                    accent = colors.purple
                )
            }
        }

        item("weekly") {
            DiaryCard(Modifier.fillMaxWidth()) {
                Column {
                    Text(
                        stringResource(R.string.weekly_writing),
                        style = MaterialTheme.typography.titleSmall,
                        color = colors.textPrimary
                    )
                    Spacer(Modifier.height(14.dp))
                    // A day was either written or it was not; there is no
                    // magnitude to scale, so the bar is full or empty.
                    WeeklyBars(
                        values = stats.weekly.map { if (it) 1f else 0f },
                        labels = stats.weeklyDates.map { formatter.digits(formatter.shortDate(it).takeWhile { c -> c != ' ' }) }
                    )
                }
            }
        }

        item("settings") { SectionHeader(stringResource(R.string.settings)) }

        item("theme") {
            DiaryCard(Modifier.fillMaxWidth()) {
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
            DiaryCard(Modifier.fillMaxWidth()) {
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

        item("lockHeader") { SectionHeader(stringResource(R.string.lock_section)) }

        item("lock") {
            DiaryCard(Modifier.fillMaxWidth()) {
                Column {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .clip(CircleShape)
                                .background(colors.tint(colors.coral)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                Icons.Rounded.Lock,
                                contentDescription = null,
                                tint = colors.onTint(colors.coral),
                                modifier = Modifier.size(20.dp)
                            )
                        }
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                stringResource(R.string.lock_section),
                                style = MaterialTheme.typography.titleSmall,
                                color = colors.textPrimary
                            )
                            Text(
                                stringResource(R.string.lock_summary),
                                style = MaterialTheme.typography.bodySmall,
                                color = colors.textSecondary
                            )
                        }
                        Switch(
                            checked = lockMode.enabled,
                            onCheckedChange = { enabled ->
                                scope.launch {
                                    mainViewModel.setLockMode(
                                        if (enabled) com.studiojavid.diary.ui.lock.LockMode.BIOMETRIC
                                        else com.studiojavid.diary.ui.lock.LockMode.NONE
                                    )
                                }
                            }
                        )
                    }
                    if (lockMode.enabled) {
                        Spacer(Modifier.height(14.dp))
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    stringResource(R.string.lock_immediate),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = colors.textPrimary
                                )
                                Text(
                                    stringResource(R.string.lock_immediate_hint),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = colors.textSecondary
                                )
                            }
                            Switch(
                                checked = lockImmediate,
                                onCheckedChange = { mainViewModel.setLockImmediate(it) }
                            )
                        }
                    }
                }
            }
        }

        item("moodHeader") { SectionHeader(stringResource(R.string.mood_breakdown)) }

        item("moods") {
            DiaryCard(Modifier.fillMaxWidth()) {
                if (stats.moodCounts.isEmpty()) {
                    Text(
                        stringResource(R.string.mood_breakdown_empty),
                        style = MaterialTheme.typography.bodyMedium,
                        color = colors.textSecondary
                    )
                } else {
                    // Shares are of the *moody* pages, not of all pages: a page
                    // saved without a mood would otherwise silently shrink every
                    // bar and make the percentages not add up.
                    val moodTotal = stats.moodCounts.values.sum().coerceAtLeast(1)
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        selectableMoods.forEach { mood ->
                            MoodBreakdownRow(
                                mood = mood,
                                count = stats.moodCounts[mood] ?: 0,
                                share = (stats.moodCounts[mood] ?: 0).toFloat() / moodTotal,
                                countLabel = formatter.digits(stats.moodCounts[mood] ?: 0)
                            )
                        }
                    }
                }
            }
        }

        item("backupHeader") { SectionHeader(stringResource(R.string.backup)) }

        item("backup") {
            DiaryCard(Modifier.fillMaxWidth()) {
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

        // Notification diagnostics: reminders depend on a permission, an exact
        // alarm capability and OEM battery policy. Surfacing all three (plus a
        // one-tap test) turns "it doesn't work" into something actionable.
        item("notifDiagnostics") {
            SectionHeader(stringResource(R.string.notif_diagnostics))
        }

        item("notifCard") {
            val activity = LocalContext.current as? MainActivity
            val notifGranted = Notifications.hasPermission(context)
            val exactGranted = remember { BirthdayScheduler(context).canScheduleExact() }

            DiaryCard(Modifier.fillMaxWidth()) {
                Column {
                    Text(
                        text = if (notifGranted) stringResource(R.string.notif_ok)
                        else stringResource(R.string.notif_blocked),
                        style = MaterialTheme.typography.titleSmall,
                        color = if (notifGranted) colors.mint else colors.danger,
                        modifier = Modifier.clickable { activity?.openNotificationSettings() }
                    )
                    if (!exactGranted) {
                        Spacer(Modifier.height(6.dp))
                        Text(
                            stringResource(R.string.notif_exact_blocked),
                            style = MaterialTheme.typography.labelSmall,
                            color = colors.orange
                        )
                    }
                    Spacer(Modifier.height(6.dp))
                    Text(
                        stringResource(R.string.notif_battery_hint),
                        style = MaterialTheme.typography.labelSmall,
                        color = colors.textSecondary
                    )
                    Spacer(Modifier.height(12.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        ActionTile(
                            modifier = Modifier.weight(1f),
                            icon = Icons.Rounded.NotificationsActive,
                            label = stringResource(R.string.notif_test),
                            accent = colors.purple,
                            onClick = {
                                Notifications.showTest(context)
                                Toast.makeText(
                                    context,
                                    context.getString(R.string.notif_test_sent),
                                    Toast.LENGTH_SHORT
                                ).show()
                            }
                        )
                        ActionTile(
                            modifier = Modifier.weight(1f),
                            icon = Icons.Rounded.Settings,
                            label = stringResource(R.string.notif_open_settings),
                            accent = colors.turquoise,
                            onClick = { activity?.openNotificationSettings() }
                        )
                    }
                }
            }
        }

        item("appFooter") {
            AppFooter()
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

}

@Composable
private fun ProfileHeader(userName: String, streakText: String, onEditName: () -> Unit) {
    val colors = DiaryTheme.colors
    DiaryCard(Modifier.fillMaxWidth()) {
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
    val colors = DiaryTheme.colors
    val preview = diaryColorsOf(option, dark)
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
    AccentCard(
        accent = accent,
        modifier = modifier,
        contentPadding = PaddingValues(vertical = 16.dp, horizontal = 12.dp)
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
            Text(
                value,
                style = MaterialTheme.typography.titleLarge.copy(shadow = accentTextShadow()),
                color = Color.White
            )
            Spacer(Modifier.height(2.dp))
            Text(
                label,
                style = MaterialTheme.typography.labelSmall.copy(shadow = accentTextShadow()),
                color = Color.White,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun ActionTile(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    accent: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier
            .clip(RoundedCornerShape(16.dp))
            .background(Brush.linearGradient(listOf(accent, accent.darken(0.12f))))
            .clickable(onClick = onClick)
            .padding(vertical = 14.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(icon, contentDescription = null, tint = Color.White)
        Spacer(Modifier.height(6.dp))
        Text(
            label,
            style = MaterialTheme.typography.labelMedium.copy(shadow = accentTextShadow()),
            color = Color.White
        )
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
        containerColor = DiaryTheme.colors.surface,
        shape = RoundedCornerShape(24.dp)
    )
}

/**
 * Version and studio credit, closing the settings list.
 *
 * The version is read from the installed package rather than BuildConfig, so it
 * always reports what the user actually has installed — including the .debug
 * suffix builds carry — instead of a constant that could drift from the APK.
 */
@Composable
private fun AppFooter() {
    val colors = DiaryTheme.colors
    val formatter = LocalDateFormatter.current
    val context = LocalContext.current

    val version = remember(context) {
        runCatching {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName
        }.getOrNull().orEmpty()
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp, bottom = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        if (version.isNotBlank()) {
            Text(
                text = stringResource(R.string.app_version, formatter.digits(version)),
                style = MaterialTheme.typography.labelMedium,
                color = colors.textSecondary
            )
            Spacer(Modifier.height(4.dp))
        }
        Text(
            text = stringResource(R.string.designed_by),
            style = MaterialTheme.typography.labelSmall,
            color = colors.textSecondary.copy(alpha = 0.75f)
        )
    }
}

/**
 * One mood's share of the diary, as a labelled bar.
 *
 * The bar is drawn even at zero so the five moods keep fixed positions and the
 * list does not reshuffle as counts change.
 */
@Composable
private fun MoodBreakdownRow(mood: Mood, count: Int, share: Float, countLabel: String) {
    val colors = DiaryTheme.colors
    val accent = mood.color()
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
        Text(mood.emoji, style = MaterialTheme.typography.bodyLarge)
        Spacer(Modifier.width(10.dp))
        Text(
            mood.label(),
            style = MaterialTheme.typography.bodySmall,
            color = colors.textSecondary,
            modifier = Modifier.width(56.dp)
        )
        Spacer(Modifier.width(8.dp))
        Box(
            Modifier
                .weight(1f)
                .height(10.dp)
                .background(colors.surfaceMuted, RoundedCornerShape(5.dp))
        ) {
            if (count > 0) {
                Box(
                    Modifier
                        .fillMaxWidth(share.coerceIn(0f, 1f))
                        .height(10.dp)
                        .background(accent, RoundedCornerShape(5.dp))
                )
            }
        }
        Spacer(Modifier.width(10.dp))
        Text(
            countLabel,
            style = MaterialTheme.typography.labelMedium,
            color = colors.textPrimary
        )
    }
}
