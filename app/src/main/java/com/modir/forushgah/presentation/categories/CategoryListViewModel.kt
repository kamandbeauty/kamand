package com.modir.forushgah.presentation.categories

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.data.repository.CategoryRepository
import com.modir.forushgah.domain.model.Category
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class CategoryListUiState(
    val isLoading: Boolean = true,
    val categories: List<Category> = emptyList(),
)

@HiltViewModel
class CategoryListViewModel @Inject constructor(
    private val categoryRepository: CategoryRepository,
) : ViewModel() {

    val uiState: StateFlow<CategoryListUiState> =
        categoryRepository.observeAll()
            .map { categories -> CategoryListUiState(isLoading = false, categories = categories) }
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), CategoryListUiState())

    fun add(name: String) {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return
        viewModelScope.launch { categoryRepository.create(trimmed) }
    }

    /** Rename preserves the existing [Category.parentId] (hierarchy stays intact). */
    fun rename(category: Category, newName: String) {
        val trimmed = newName.trim()
        if (trimmed.isEmpty()) return
        viewModelScope.launch { categoryRepository.rename(category.id, trimmed, category.parentId) }
    }

    fun archive(categoryId: Long) {
        viewModelScope.launch { categoryRepository.archive(categoryId) }
    }
}
