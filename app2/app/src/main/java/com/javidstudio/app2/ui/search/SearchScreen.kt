package com.javidstudio.app2.ui.search

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.javidstudio.app2.R
import com.javidstudio.app2.data.local.Priority
import com.javidstudio.app2.data.repo.Task
import com.javidstudio.app2.ui.LocalDateFormatter
import com.javidstudio.app2.ui.TaskFilter
import com.javidstudio.app2.ui.TasksViewModel
import com.javidstudio.app2.ui.components.ChipRow
import com.javidstudio.app2.ui.components.EmptyState
import com.javidstudio.app2.ui.components.SwipeableTaskCard
import com.javidstudio.app2.ui.displayName
import com.javidstudio.app2.ui.theme.App2Theme

@Composable
fun SearchScreen(
    viewModel: TasksViewModel,
    onBack: () -> Unit,
    onOpenTask: (Task) -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = App2Theme.colors
    val formatter = LocalDateFormatter.current
    val query by viewModel.query.collectAsStateWithLifecycle()
    val filter by viewModel.filter.collectAsStateWithLifecycle()
    val results by viewModel.searchResults.collectAsStateWithLifecycle()
    val focusRequester = remember { FocusRequester() }

    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(150)
        runCatching { focusRequester.requestFocus() }
    }

    Column(
        modifier
            .fillMaxSize()
            .background(colors.background)
            // This screen hides the app header, so it owns the status bar inset
            // itself; without this the search field sits under the clock.
            .statusBarsPadding()
            .padding(top = 12.dp)
    ) {
        Column(Modifier.padding(horizontal = 16.dp)) {
            OutlinedTextField(
                value = query,
                onValueChange = viewModel::setQuery,
                modifier = Modifier.fillMaxWidth().focusRequester(focusRequester),
                placeholder = { Text(stringResource(R.string.search_hint)) },
                leadingIcon = { Icon(Icons.Rounded.Search, contentDescription = null) },
                trailingIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.AutoMirrored.Rounded.ArrowBack,
                            contentDescription = stringResource(R.string.cd_back)
                        )
                    }
                },
                singleLine = true,
                shape = RoundedCornerShape(18.dp),
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = colors.surfaceMuted,
                    unfocusedContainerColor = colors.surfaceMuted,
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent,
                    cursorColor = colors.coral
                )
            )
        }
        Spacer(Modifier.height(10.dp))
        ChipRow(
            items = TaskFilter.entries.toList(),
            selected = filter,
            onSelect = viewModel::setFilter,
            label = {
                stringResource(
                    when (it) {
                        TaskFilter.ALL -> R.string.filter_all
                        TaskFilter.TODAY -> R.string.filter_today
                        TaskFilter.NO_DATE -> R.string.filter_no_date
                        TaskFilter.UNDONE -> R.string.filter_undone
                        TaskFilter.DONE -> R.string.filter_done
                        TaskFilter.IMPORTANT -> R.string.filter_important
                    }
                )
            },
            accent = { colors.coral },
            contentPadding = PaddingValues(horizontal = 16.dp),
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(8.dp))

        if (results.isEmpty()) {
            EmptyState(title = stringResource(R.string.empty_search))
        } else {
            LazyColumn(
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                items(results, key = { it.id }) { task ->
                    val subtitle = buildString {
                        append(
                            task.dueDate?.let { formatter.relativeDate(it) }
                                ?: stringResource(R.string.section_no_date)
                        )
                        task.dueTimeMinutes?.let { append(" · "); append(formatter.time(it)) }
                    }
                    SwipeableTaskCard(
                        task = task,
                        subtitle = subtitle,
                        categoryLabel = task.category?.displayName(),
                        priorityLabel = stringResource(
                            when (task.priority) {
                                Priority.LOW -> R.string.priority_low
                                Priority.MEDIUM -> R.string.priority_medium
                                Priority.HIGH -> R.string.priority_high
                            }
                        ),
                        onToggle = { viewModel.toggleTask(task) },
                        onClick = { onOpenTask(task) },
                        onDelete = { viewModel.deleteTask(task) },
                        modifier = Modifier.animateItem()
                    )
                }
            }
        }
    }
}
