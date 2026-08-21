package com.studiojavid.diary.ui.search

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
import com.studiojavid.diary.R
import com.studiojavid.diary.ui.LocalDateFormatter
import com.studiojavid.diary.ui.DiaryFilter
import com.studiojavid.diary.ui.DiaryViewModel
import com.studiojavid.diary.ui.components.ChipRow
import com.studiojavid.diary.ui.components.EmptyState
import com.studiojavid.diary.ui.components.DiaryPageCard
import com.studiojavid.diary.ui.theme.DiaryTheme
import java.time.LocalDate

@Composable
fun SearchScreen(
    viewModel: DiaryViewModel,
    onBack: () -> Unit,
    onOpenPage: (LocalDate) -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = DiaryTheme.colors
    val formatter = LocalDateFormatter.current
    val query by viewModel.query.collectAsStateWithLifecycle()
    val filter by viewModel.filter.collectAsStateWithLifecycle()
    val results by viewModel.pages.collectAsStateWithLifecycle()
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
            items = DiaryFilter.entries.toList(),
            selected = filter,
            onSelect = viewModel::setFilter,
            label = {
                stringResource(
                    when (it) {
                        DiaryFilter.ALL -> R.string.filter_all
                        DiaryFilter.FAVORITES -> R.string.filter_favorites
                        DiaryFilter.WITH_PHOTO -> R.string.filter_with_photo
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
                items(results, key = { it.id }) { page ->
                    DiaryPageCard(
                        page = page,
                        dateLabel = formatter.weekdayAndDate(page.date),
                        photo = viewModel.photoFile(page.photo),
                        onClick = { onOpenPage(page.date) },
                        onToggleFavorite = { viewModel.toggleFavorite(page) },
                        modifier = Modifier.animateItem()
                    )
                }
            }
        }
    }
}
