package com.javidstudio.app2.ui.today

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Owns the "signature" completion animation state.
 *
 * ### Why this exists
 * The database updates the instant a task is ticked, which immediately moves
 * the task from the pending section to the completed one. Because the two
 * sections use different list keys, Compose destroys and recreates the row, and
 * any animation started inside it is lost — the strike-through simply appeared
 * fully drawn.
 *
 * This holder keeps a short-lived, purely visual record of "this task is being
 * completed right now", entirely separate from the persisted task state. That
 * satisfies two requirements at once:
 *
 *  - the pen animation plays exactly once, on a real incomplete → complete
 *    transition (not on recomposition, scroll, navigation, rotation or restart,
 *    because nothing re-seeds this map on those events);
 *  - the row can stay visually in place until the stroke finishes.
 */
class CompletionAnimator(private val scope: CoroutineScope) {

    /** Task ids currently playing the pen animation. */
    private val animating = mutableStateMapOf<Long, Boolean>()

    /** Ids that already finished animating in this session. */
    private val settled = mutableStateMapOf<Long, Boolean>()

    var reduceMotion: Boolean by mutableStateOf(false)

    fun isAnimating(taskId: Long): Boolean = animating.containsKey(taskId)

    /**
     * True while the row should keep rendering in its original section so the
     * stroke can finish before it moves.
     */
    fun holdsPosition(taskId: Long): Boolean = animating.containsKey(taskId)

    /**
     * Marks a real completion transition. Returns true when the caller should
     * animate; false when the change should apply instantly (uncheck, repeat
     * of an already-settled task, or reduced motion).
     */
    fun onCompleted(taskId: Long): Boolean {
        if (reduceMotion) return false
        if (animating.containsKey(taskId)) return false
        animating[taskId] = true
        scope.launch {
            delay(TOTAL_DURATION_MS)
            animating.remove(taskId)
            settled[taskId] = true
        }
        return true
    }

    /** A task returning to active clears its animation bookkeeping. */
    fun onUncompleted(taskId: Long) {
        animating.remove(taskId)
        settled.remove(taskId)
    }

    companion object {
        /** Pen enters, draws, leaves — inside the 500..800ms budget. */
        const val PEN_ENTER_MS = 140
        const val PEN_DRAW_MS = 380
        const val PEN_EXIT_MS = 140
        const val TOTAL_DURATION_MS = (PEN_ENTER_MS + PEN_DRAW_MS + PEN_EXIT_MS).toLong()
    }
}

@Composable
fun rememberCompletionAnimator(scope: CoroutineScope, reduceMotion: Boolean): CompletionAnimator {
    val animator = remember(scope) { CompletionAnimator(scope) }
    animator.reduceMotion = reduceMotion
    return animator
}
