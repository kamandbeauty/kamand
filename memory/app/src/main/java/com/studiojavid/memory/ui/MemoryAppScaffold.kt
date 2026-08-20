package com.studiojavid.memory.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.layout.PaddingValues
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
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.lifecycle.viewmodel.compose.viewModel
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
import com.studiojavid.memory.data.repo.Task
import com.studiojavid.memory.navigation.Routes
import com.studiojavid.memory.navigation.TopLevelDestination
import com.studiojavid.memory.ui.addtask.AddTaskSheet
import com.studiojavid.memory.ui.components.TaskActionsSheet
import com.studiojavid.memory.ui.calendar.CalendarScreen
import com.studiojavid.memory.ui.birthday.BirthdayScreen
import com.studiojavid.memory.ui.birthday.MessagePickerScreen
import com.studiojavid.memory.ui.birthday.PersonDetailScreen
import com.studiojavid.memory.ui.birthday.PersonEditorSheet
import com.studiojavid.memory.ui.notes.NoteEditorSheet
import com.studiojavid.memory.ui.notes.NotebookDialog
import com.studiojavid.memory.ui.notes.NotesScreen
import com.studiojavid.memory.ui.profile.ProfileScreen
import com.studiojavid.memory.ui.components.MemoryHeader
import com.studiojavid.memory.ui.components.liquidGlassSource
import com.studiojavid.memory.ui.components.rememberLiquidGlassState
import com.studiojavid.memory.ui.search.SearchScreen
import com.studiojavid.memory.ui.theme.MemoryTheme
import com.studiojavid.memory.ui.theme.ThemePalette
import com.studiojavid.memory.ui.today.TodayScreen
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MemoryAppScaffold(
    tasksViewModel: TasksViewModel,
    mainViewModel: MainViewModel,
    backupManager: BackupManager,
    userName: String,
    theme: ThemeMode,
    language: AppLanguage,
    palette: ThemePalette,
    onRequestNotificationPermission: () -> Unit,
    modifier: Modifier = Modifier,
    /** Opens the add sheet immediately (launched from the Quick Add widget). */
    openAddSheet: Boolean = false,
    onAddSheetOpened: () -> Unit = {}
) {
    val colors = MemoryTheme.colors
    val outlineColor = colors.outline
    val navController = rememberNavController()
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route
    val scope = rememberCoroutineScope()
    val snackbarHostState = remember { SnackbarHostState() }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    var sheetVisible by remember { mutableStateOf(false) }
    var editingTask by remember { mutableStateOf<Task?>(null) }
    var actionsTask by remember { mutableStateOf<Task?>(null) }

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
    val actionsSheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    val categories by tasksViewModel.categories.collectAsStateWithLifecycle()
    val selectedDate by tasksViewModel.selectedDate.collectAsStateWithLifecycle()
    val lastDeleted by tasksViewModel.lastDeleted.collectAsStateWithLifecycle()

    val deletedMessage = stringResource(R.string.task_deleted)
    val undoLabel = stringResource(R.string.undo)

    LaunchedEffect(lastDeleted) {
        val task = lastDeleted ?: return@LaunchedEffect
        val result = snackbarHostState.showSnackbar(
            message = deletedMessage,
            actionLabel = undoLabel,
            duration = SnackbarDuration.Short
        )
        if (result == SnackbarResult.ActionPerformed) tasksViewModel.undoDelete()
        else tasksViewModel.clearLastDeleted()
    }

    val noteDeletedMessage = stringResource(R.string.note_deleted)
    LaunchedEffect(lastDeletedNote) {
        val note = lastDeletedNote ?: return@LaunchedEffect
        val result = snackbarHostState.showSnackbar(
            message = noteDeletedMessage,
            actionLabel = undoLabel,
            duration = SnackbarDuration.Short
        )
        if (result == SnackbarResult.ActionPerformed) notesViewModel.undoDelete()
        else notesViewModel.clearLastDeleted()
    }

    // Keep "today" fresh when the app returns from the background across midnight.
    LaunchedEffect(Unit) { tasksViewModel.refreshToday() }

    LaunchedEffect(openAddSheet) {
        if (openAddSheet) {
            editingTask = null
            sheetVisible = true
            onAddSheetOpened()
        }
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
                                        popUpTo(TopLevelDestination.TODAY.route) { saveState = true }
                                        launchSingleTop = true
                                        restoreState = true
                                    }
                                }
                            },
                            icon = {
                                Icon(destination.icon, contentDescription = stringResource(destination.labelRes))
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
                val onBirthdays = currentRoute == Routes.BIRTHDAYS
                val onNotesTab = currentRoute == TopLevelDestination.NOTES.route
                FloatingActionButton(
                    onClick = {
                        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                        if (onBirthdays) {
                            editingPerson = null
                            personSheetVisible = true
                            onRequestNotificationPermission()
                        } else if (onNotesTab) {
                            editingNote = null
                            noteSheetVisible = true
                        } else {
                            editingTask = null
                            sheetVisible = true
                            onRequestNotificationPermission()
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
                                    else -> R.string.cd_add_task
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
            startDestination = TopLevelDestination.TODAY.route,
            modifier = Modifier
                .fillMaxSize()
                .liquidGlassSource(glass),
            enterTransition = { fadeIn(androidx.compose.animation.core.tween(220)) },
            exitTransition = { fadeOut(androidx.compose.animation.core.tween(160)) }
        ) {
            composable(TopLevelDestination.TODAY.route) {
                TodayScreen(
                    viewModel = tasksViewModel,
                    userName = userName,
                    contentPadding = padding,
                    onOpenTask = { task ->
                        editingTask = task
                        sheetVisible = true
                    },
                    onTaskActions = { task -> actionsTask = task }
                )
            }
            composable(TopLevelDestination.CALENDAR.route) {
                CalendarScreen(
                    viewModel = tasksViewModel,
                    contentPadding = padding,
                    onOpenTask = { task ->
                        editingTask = task
                        sheetVisible = true
                    },
                    onTaskActions = { task -> actionsTask = task }
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
                    onEditNotebook = { book -> notebookDialog = NotebookDialogRequest(book) },
                    onOpenBirthdays = { navController.navigate(Routes.BIRTHDAYS) }
                )
            }

            composable(Routes.BIRTHDAYS) {
                BirthdayScreen(
                    viewModel = birthdayViewModel,
                    contentPadding = padding,
                    onBack = { navController.popBackStack() },
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
                    tasksViewModel = tasksViewModel,
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
                    viewModel = tasksViewModel,
                    onBack = { navController.popBackStack() },
                    onOpenTask = { task ->
                        editingTask = task
                        sheetVisible = true
                    }
                )
            }
        }
    }

    if (sheetVisible) {
        val formatter = LocalDateFormatter.current
        AddTaskSheet(
            sheetState = sheetState,
            formatter = formatter,
            categories = categories,
            editing = editingTask,
            defaultDate = selectedDate,
            onDismiss = {
                sheetVisible = false
                editingTask = null
            },
            onReminderEnabled = onRequestNotificationPermission,
            onSave = { draft ->
                tasksViewModel.saveTask(
                    id = draft.id,
                    title = draft.title,
                    description = draft.description,
                    categoryId = draft.categoryId,
                    dueDate = draft.dueDate,
                    dueTimeMinutes = draft.dueTimeMinutes,
                    priority = draft.priority,
                    reminderEnabled = draft.reminderEnabled,
                    repeat = draft.repeat
                )
                scope.launch {
                    sheetState.hide()
                    sheetVisible = false
                    editingTask = null
                }
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

    actionsTask?.let { task ->
        val formatter = LocalDateFormatter.current
        fun close() {
            scope.launch {
                actionsSheetState.hide()
                actionsTask = null
            }
        }
        TaskActionsSheet(
            sheetState = actionsSheetState,
            task = task,
            formatter = formatter,
            onDismiss = { actionsTask = null },
            onEdit = {
                actionsTask = null
                editingTask = task
                sheetVisible = true
            },
            onToggleComplete = {
                tasksViewModel.toggleTask(task)
                close()
            },
            onMoveTo = { date ->
                tasksViewModel.moveTask(task, date)
                close()
            },
            onToggleReminder = { enabled ->
                if (enabled) onRequestNotificationPermission()
                tasksViewModel.setReminder(task, enabled)
                close()
            },
            onDelete = {
                tasksViewModel.deleteTask(task)
                close()
            }
        )
    }
}

/** Wrapper so `null` can mean "create" while still using a nullable state. */
private data class NotebookDialogRequest(val notebook: Notebook?)
