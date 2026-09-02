package com.roozi.app.ui.today

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.roozi.app.data.repo.Task

/**
 * Lightweight long-press reordering for a single list section.
 *
 * The list is mutated optimistically while dragging so the UI feels instant,
 * and the final order is written to the database once, on drop — no write
 * amplification during the gesture.
 */
class ReorderState internal constructor(
    initial: List<Task>,
    private val onCommit: (List<Long>) -> Unit
) {
    /**
     * Backed by mutableStateOf so that *replacing* the list is observable.
     * A plain `var` holding a SnapshotStateList would only publish in-place
     * mutations, and a freshly added task would never show up.
     */
    var items: List<Task> by mutableStateOf(initial)
        private set

    var draggingId: Long? by mutableStateOf(null)
        private set

    var dragOffset: Float by mutableFloatStateOf(0f)
        private set

    private var accumulated = 0f

    /**
     * Re-syncs from the database while no drag is in progress.
     *
     * Must be called from a side effect, never straight from composition:
     * writing snapshot state during composition throws at draw time
     * ("Cannot modify state during composition") and takes the app down.
     */
    internal fun syncFrom(source: List<Task>) {
        if (draggingId != null) return
        if (items != source) items = source
    }

    fun onDragStart(id: Long) {
        draggingId = id
        dragOffset = 0f
        accumulated = 0f
    }

    /**
     * @param delta vertical movement since the last event
     * @param rowHeight approximate row height in pixels; one row of travel
     *        swaps the dragged item with its neighbour.
     */
    fun onDrag(delta: Float, rowHeight: Float) {
        val id = draggingId ?: return
        dragOffset += delta
        accumulated += delta

        val index = items.indexOfFirst { it.id == id }
        if (index < 0) return

        if (accumulated >= rowHeight && index < items.lastIndex) {
            items = items.toMutableList().apply { add(index + 1, removeAt(index)) }
            accumulated -= rowHeight
            dragOffset -= rowHeight
        } else if (accumulated <= -rowHeight && index > 0) {
            items = items.toMutableList().apply { add(index - 1, removeAt(index)) }
            accumulated += rowHeight
            dragOffset += rowHeight
        }
    }

    fun onDragEnd() {
        if (draggingId != null) onCommit(items.map { it.id })
        draggingId = null
        dragOffset = 0f
        accumulated = 0f
    }
}

@Composable
fun rememberReorderState(
    items: List<Task>,
    onCommit: (List<Long>) -> Unit
): ReorderState {
    val state = remember { ReorderState(items, onCommit) }
    // Sync in a side effect: doing it inline would mutate snapshot state while
    // the composition is running, which Compose rejects.
    LaunchedEffect(items) { state.syncFrom(items) }
    return state
}
