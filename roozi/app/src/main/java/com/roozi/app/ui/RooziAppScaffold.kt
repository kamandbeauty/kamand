package com.roozi.app.ui

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
import androidx.compose.material.icons.rounded.Search
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
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.IconButton
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
import com.roozi.app.R
import com.roozi.app.data.backup.BackupManager
import com.roozi.app.data.prefs.AppLanguage
import com.roozi.app.data.prefs.ThemeMode
import com.roozi.app.data.repo.Note
import com.roozi.app.data.repo.Notebook
import com.roozi.app.data.repo.Task
import com.roozi.app.navigation.Routes
import com.roozi.app.navigation.TopLevelDestination
import com.roozi.app.ui.addtask.AddTaskSheet
import com.roozi.app.ui.components.TaskActionsSheet
import com.roozi.app.ui.calendar.CalendarScreen
import com.roozi.app.ui.notes.NoteEditorSheet
import com.roozi.app.ui.notes.NotebookDialog
import com.roozi.app.ui.notes.NotesScreen
import com.roozi.app.ui.profile.ProfileScreen
import com.roozi.app.ui.search.SearchScreen
import com.roozi.app.ui.theme.RooziTheme
import com.roozi.app.ui.theme.ThemePalette
import com.roozi.app.ui.today.TodayScreen
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RooziAppScaffold(
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
    val colors = RooziTheme.colors
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

    val showBars = currentRoute != Routes.SEARCH

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = colors.background,
        contentColor = colors.textPrimary,
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            AnimatedVisibility(visible = showBars, enter = fadeIn(), exit = fadeOut()) {
                TopAppBar(
                    title = { Text(stringResource(R.string.app_name)) },
                    actions = {
                        IconButton(onClick = { navController.navigate(Routes.SEARCH) }) {
                            Icon(
                                Icons.Rounded.Search,
                                contentDescription = stringResource(R.string.search),
                                tint = colors.textSecondary
                            )
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = Color.Transparent,
                        titleContentColor = colors.textPrimary
                    )
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
            AnimatedVisibility(
                visible = showBars,
                enter = scaleIn(spring(dampingRatio = 0.55f)) + fadeIn(),
                exit = scaleOut() + fadeOut()
            ) {
                val haptics = LocalHapticFeedback.current
                val onNotesTab = currentRoute == TopLevelDestination.NOTES.route
                FloatingActionButton(
                    onClick = {
                        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                        if (onNotesTab) {
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
                                if (onNotesTab) R.string.cd_add_note else R.string.cd_add_task
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
            modifier = Modifier.fillMaxSize(),
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
                    onEditNotebook = { book -> notebookDialog = NotebookDialogRequest(book) }
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
