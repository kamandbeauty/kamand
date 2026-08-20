package com.studiojavid.memory.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.FloatingActionButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.studiojavid.memory.R
import com.studiojavid.memory.data.backup.BackupManager
import com.studiojavid.memory.data.prefs.AppLanguage
import com.studiojavid.memory.data.prefs.ThemeMode
import com.studiojavid.memory.data.repo.BirthdayPerson
import com.studiojavid.memory.data.repo.Note
import com.studiojavid.memory.data.repo.Notebook
import com.studiojavid.memory.navigation.Routes
import com.studiojavid.memory.navigation.TopLevelDestination
import com.studiojavid.memory.ui.birthday.BirthdayScreen
import com.studiojavid.memory.ui.birthday.MessagePickerScreen
import com.studiojavid.memory.ui.birthday.PersonDetailScreen
import com.studiojavid.memory.ui.birthday.PersonEditorSheet
import com.studiojavid.memory.ui.calendar.CalendarScreen
import com.studiojavid.memory.ui.components.MemoryHeader
import com.studiojavid.memory.ui.components.liquidGlassSource
import com.studiojavid.memory.ui.components.rememberLiquidGlassState
import com.studiojavid.memory.ui.diary.DiaryScreen
import com.studiojavid.memory.ui.diary.MemoryEditorSheet
import com.studiojavid.memory.ui.notes.NoteEditorSheet
import com.studiojavid.memory.ui.notes.NotebookDialog
import com.studiojavid.memory.ui.notes.NotesScreen
import com.studiojavid.memory.ui.profile.ProfileScreen
import com.studiojavid.memory.ui.search.SearchScreen
import com.studiojavid.memory.ui.theme.MemoryTheme
import com.studiojavid.memory.ui.theme.ThemePalette
import kotlinx.coroutines.launch
import java.time.LocalDate

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MemoryAppScaffold(
    memoryViewModel: MemoryViewModel,
    mainViewModel: MainViewModel,
    backupManager: BackupManager,
    userName: String,
    theme: ThemeMode,
    language: AppLanguage,
    palette: ThemePalette,
    onRequestNotificationPermission: () -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = MemoryTheme.colors
    val outlineColor = colors.outline
    val navController = rememberNavController()
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route
    val scope = rememberCoroutineScope()
    val snackbarHostState = remember { SnackbarHostState() }

    // Diary editor
    val editorSheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var editorDate by remember { mutableStateOf<LocalDate?>(null) }

    // Notes tab state
    val notesViewModel: NotesViewModel = viewModel(factory = NotesViewModel.Factory)
    val noteSheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var noteSheetVisible by remember { mutableStateOf(false) }
    var editingNote by remember { mutableStateOf<Note?>(null) }
    var notebookDialog by remember { mutableStateOf<NotebookDialogRequest?>(null) }

    // Birthday notebook
    val birthdayViewModel: BirthdayViewModel = viewModel(factory = BirthdayViewModel.Factory)
    val personSheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var personSheetVisible by remember { mutableStateOf(false) }
    var editingPerson by remember { mutableStateOf<BirthdayPerson?>(null) }
    val openPerson by birthdayViewModel.openPerson.collectAsStateWithLifecycle()

    val notebooks by notesViewModel.notebooks.collectAsStateWithLifecycle()
    val noteFilter by notesViewModel.filter.collectAsStateWithLifecycle()
    val lastDeletedNote by notesViewModel.lastDeleted.collectAsStateWithLifecycle()

    val today by memoryViewModel.today.collectAsStateWithLifecycle()
    val diary by memoryViewModel.diary.collectAsStateWithLifecycle()
    val lastDeleted by memoryViewModel.lastDeleted.collectAsStateWithLifecycle()

    val deletedMessage = stringResource(R.string.memory_deleted)
    val undoLabel = stringResource(R.string.undo)

    LaunchedEffect(lastDeleted) {
        lastDeleted ?: return@LaunchedEffect
        val result = snackbarHostState.showSnackbar(
            message = deletedMessage,
            actionLabel = undoLabel,
            duration = SnackbarDuration.Short
        )
        if (result == SnackbarResult.ActionPerformed) memoryViewModel.undoDelete()
        else memoryViewModel.clearLastDeleted()
    }

    val noteDeletedMessage = stringResource(R.string.note_deleted)
    LaunchedEffect(lastDeletedNote) {
        lastDeletedNote ?: return@LaunchedEffect
        val result = snackbarHostState.showSnackbar(
            message = noteDeletedMessage,
            actionLabel = undoLabel,
            duration = SnackbarDuration.Short
        )
        if (result == SnackbarResult.ActionPerformed) notesViewModel.undoDelete()
        else notesViewModel.clearLastDeleted()
    }

    // Keep "today" fresh when the app returns from the background across midnight.
    LaunchedEffect(Unit) { memoryViewModel.refreshToday() }

    /** Opening a day both selects it and raises the editor on that day. */
    fun openPage(date: LocalDate) {
        memoryViewModel.selectDate(date)
        editorDate = minOf(date, today)
    }

    val showBars = currentRoute !in setOf(
        Routes.SEARCH,
        Routes.BIRTHDAY_PERSON,
        Routes.BIRTHDAY_MESSAGES
    )

    // Backdrop the header refracts. Captured from the page content below.
    val glass = rememberLiquidGlassState()

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = colors.background,
        contentColor = colors.textPrimary,
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            AnimatedVisibility(visible = showBars, enter = fadeIn(), exit = fadeOut()) {
                MemoryHeader(
                    onSearch = { navController.navigate(Routes.SEARCH) },
                    glass = glass
                )
            }
        },
        bottomBar = {
            AnimatedVisibility(
                visible = showBars,
                enter = fadeIn() + slideInHorizontally(),
                exit = fadeOut() + slideOutHorizontally()
            ) {
                NavigationBar(
                    containerColor = colors.surface,
                    tonalElevation = 0.dp,
                    modifier = Modifier.drawWithContent {
                        drawContent()
                        // Hairline instead of a shadow, so the bar reads as part
                        // of the page rather than a floating slab.
                        drawLine(
                            color = outlineColor,
                            start = Offset(0f, 0f),
                            end = Offset(size.width, 0f),
                            strokeWidth = 1f
                        )
                    }
                ) {
                    TopLevelDestination.entries.forEach { destination ->
                        val selected = backStackEntry?.destination?.hierarchy
                            ?.any { it.route == destination.route } == true
                        NavigationBarItem(
                            selected = selected,
                            onClick = {
                                if (!selected) {
                                    navController.navigate(destination.route) {
                                        popUpTo(TopLevelDestination.DIARY.route) { saveState = true }
                                        launchSingleTop = true
                                        restoreState = true
                                    }
                                }
                            },
                            icon = {
                                Icon(
                                    destination.icon,
                                    contentDescription = stringResource(destination.labelRes)
                                )
                            },
                            label = { Text(stringResource(destination.labelRes)) },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = colors.coral,
                                selectedTextColor = colors.coral,
                                indicatorColor = colors.tint(colors.coral),
                                unselectedIconColor = colors.textSecondary,
                                unselectedTextColor = colors.textSecondary
                            )
                        )
                    }
                }
            }
        },
        floatingActionButton = {
            // Profile is settings, not a collection — there is nothing to
            // create there, so the button would do nothing meaningful.
            val canCreate = currentRoute != TopLevelDestination.PROFILE.route
            AnimatedVisibility(
                visible = showBars && canCreate,
                enter = scaleIn(spring(dampingRatio = 0.55f)) + fadeIn(),
                exit = scaleOut() + fadeOut()
            ) {
                val haptics = LocalHapticFeedback.current
                val onBirthdays = currentRoute == TopLevelDestination.BIRTHDAYS.route
                val onNotesTab = currentRoute == TopLevelDestination.NOTES.route
                FloatingActionButton(
                    onClick = {
                        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                        when {
                            onBirthdays -> {
                                editingPerson = null
                                personSheetVisible = true
                                onRequestNotificationPermission()
                            }
                            onNotesTab -> {
                                editingNote = null
                                noteSheetVisible = true
                            }
                            // On the calendar the button writes the day the user
                            // is looking at; anywhere else it writes today.
                            currentRoute == TopLevelDestination.CALENDAR.route ->
                                openPage(memoryViewModel.selectedDate.value)
                            else -> openPage(today)
                        }
                    },
                    containerColor = Color.Transparent,
                    contentColor = Color.White,
                    shape = CircleShape,
                    elevation = FloatingActionButtonDefaults.elevation(
                        defaultElevation = 8.dp,
                        pressedElevation = 4.dp
                    ),
                    modifier = Modifier.size(62.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(
                                Brush.linearGradient(listOf(colors.coral, colors.purple)),
                                CircleShape
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            Icons.Rounded.Add,
                            contentDescription = stringResource(
                                when {
                                    onBirthdays -> R.string.cd_add_birthday
                                    onNotesTab -> R.string.cd_add_note
                                    else -> R.string.cd_add_memory
                                }
                            ),
                            modifier = Modifier.size(28.dp)
                        )
                    }
                }
            }
        }
    ) { padding ->
        NavHost(
            navController = navController,
            startDestination = TopLevelDestination.DIARY.route,
            modifier = Modifier
                .fillMaxSize()
                .liquidGlassSource(glass),
            enterTransition = { fadeIn(androidx.compose.animation.core.tween(220)) },
            exitTransition = { fadeOut(androidx.compose.animation.core.tween(160)) }
        ) {
            composable(TopLevelDestination.DIARY.route) {
                DiaryScreen(
                    viewModel = memoryViewModel,
                    userName = userName,
                    contentPadding = padding,
                    onOpenPage = ::openPage
                )
            }
            composable(TopLevelDestination.CALENDAR.route) {
                CalendarScreen(
                    viewModel = memoryViewModel,
                    contentPadding = padding,
                    onOpenPage = ::openPage
                )
            }
            composable(TopLevelDestination.NOTES.route) {
                NotesScreen(
                    viewModel = notesViewModel,
                    contentPadding = padding,
                    onOpenNote = { note ->
                        editingNote = note
                        noteSheetVisible = true
                    },
                    onEditNotebook = { book -> notebookDialog = NotebookDialogRequest(book) }
                )
            }

            composable(TopLevelDestination.BIRTHDAYS.route) {
                BirthdayScreen(
                    viewModel = birthdayViewModel,
                    contentPadding = padding,
                    onAddPerson = {
                        editingPerson = null
                        personSheetVisible = true
                    },
                    onOpenPerson = { person ->
                        birthdayViewModel.openPerson(person.id)
                        navController.navigate(Routes.BIRTHDAY_PERSON)
                    }
                )
            }

            composable(Routes.BIRTHDAY_PERSON) {
                val person = openPerson
                if (person == null) {
                    // The person was deleted while open; fall back rather than
                    // showing an empty screen.
                    LaunchedEffect(Unit) { navController.popBackStack() }
                } else {
                    PersonDetailScreen(
                        viewModel = birthdayViewModel,
                        person = person,
                        contentPadding = padding,
                        onBack = { navController.popBackStack() },
                        onEdit = {
                            editingPerson = person
                            personSheetVisible = true
                        },
                        onPickMessage = { navController.navigate(Routes.BIRTHDAY_MESSAGES) }
                    )
                }
            }

            composable(Routes.BIRTHDAY_MESSAGES) {
                val person = openPerson
                MessagePickerScreen(
                    personName = person?.name,
                    selectedMessageId = person?.favoriteMessageId ?: 0,
                    contentPadding = padding,
                    onBack = { navController.popBackStack() },
                    onUseMessage = { messageId ->
                        person?.let { birthdayViewModel.setFavoriteMessage(it.id, messageId) }
                    }
                )
            }
            composable(TopLevelDestination.PROFILE.route) {
                ProfileScreen(
                    memoryViewModel = memoryViewModel,
                    mainViewModel = mainViewModel,
                    backupManager = backupManager,
                    userName = userName,
                    theme = theme,
                    language = language,
                    palette = palette,
                    contentPadding = padding
                )
            }
            composable(Routes.SEARCH) {
                SearchScreen(
                    viewModel = memoryViewModel,
                    onBack = { navController.popBackStack() },
                    onOpenPage = { date ->
                        navController.popBackStack()
                        openPage(date)
                    }
                )
            }
        }
    }

    editorDate?.let { date ->
        val formatter = LocalDateFormatter.current
        val existing = diary.page?.takeIf { it.date == date }
        fun close() {
            scope.launch {
                editorSheetState.hide()
                editorDate = null
            }
        }
        MemoryEditorSheet(
            sheetState = editorSheetState,
            date = date,
            formatter = formatter,
            editing = existing,
            photoFile = memoryViewModel::photoFile,
            onPickPhoto = { uri, onStored -> memoryViewModel.importPhoto(uri, onStored) },
            // A day with no page has nothing to delete, so the button is absent
            // rather than present and inert.
            onDelete = if (existing == null) null else {
                {
                    memoryViewModel.deletePage(existing)
                    close()
                }
            },
            onDismiss = { editorDate = null },
            onSave = { draft ->
                memoryViewModel.savePage(
                    date = draft.date,
                    title = draft.title,
                    body = draft.body,
                    mood = draft.mood,
                    tags = draft.tags,
                    photo = draft.photo,
                    favorite = draft.favorite
                )
                close()
            }
        )
    }

    if (noteSheetVisible) {
        NoteEditorSheet(
            sheetState = noteSheetState,
            editing = editingNote,
            notebooks = notebooks,
            // A new note lands in the notebook the user is currently browsing.
            defaultNotebookId = (noteFilter as? NoteFilter.InNotebook)?.notebookId,
            onDismiss = {
                noteSheetVisible = false
                editingNote = null
            },
            onSave = { draft ->
                notesViewModel.saveNote(
                    id = draft.id,
                    title = draft.title,
                    body = draft.body,
                    notebookId = draft.notebookId,
                    color = draft.color,
                    pinned = draft.pinned
                )
                scope.launch {
                    noteSheetState.hide()
                    noteSheetVisible = false
                    editingNote = null
                }
            }
        )
    }

    notebookDialog?.let { request ->
        NotebookDialog(
            editing = request.notebook,
            onDismiss = { notebookDialog = null },
            onConfirm = { name, icon, color ->
                val existing = request.notebook
                if (existing == null) notesViewModel.addNotebook(name, icon, color)
                else notesViewModel.updateNotebook(existing, name, icon, color)
                notebookDialog = null
            },
            onDelete = request.notebook?.takeIf { !it.isBuiltIn }?.let { book ->
                {
                    notesViewModel.deleteNotebook(book)
                    notebookDialog = null
                }
            }
        )
    }

    if (personSheetVisible) {
        val formatter = LocalDateFormatter.current
        PersonEditorSheet(
            sheetState = personSheetState,
            formatter = formatter,
            editing = editingPerson,
            onDismiss = {
                personSheetVisible = false
                editingPerson = null
            },
            onDelete = editingPerson?.let { person ->
                {
                    birthdayViewModel.deletePerson(person)
                    scope.launch {
                        personSheetState.hide()
                        personSheetVisible = false
                        editingPerson = null
                    }
                }
            },
            onSave = { draft ->
                birthdayViewModel.savePerson(
                    id = draft.id,
                    name = draft.name,
                    birthMonth = draft.birthMonth,
                    birthDay = draft.birthDay,
                    birthYear = draft.birthYear,
                    relationship = draft.relationship,
                    avatar = draft.avatar,
                    notes = draft.notes,
                    reminderEnabled = draft.reminderEnabled,
                    reminderOffset = draft.reminderOffset
                )
                scope.launch {
                    personSheetState.hide()
                    personSheetVisible = false
                    editingPerson = null
                }
            }
        )
    }
}

/** Wrapper so `null` can mean "create" while still using a nullable state. */
private data class NotebookDialogRequest(val notebook: Notebook?)
