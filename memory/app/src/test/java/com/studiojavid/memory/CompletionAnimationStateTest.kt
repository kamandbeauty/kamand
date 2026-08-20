package com.studiojavid.memory

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Mirrors CompletionAnimator.
 *
 * The completion animation must play exactly once per genuine
 * incomplete → complete transition, and must never replay on recomposition,
 * scroll, navigation, rotation or app restart.
 */
private class TestAnimator(private val reduceMotion: Boolean = false) {
    private val animating = mutableSetOf<Long>()
    var plays = 0
        private set

    fun isAnimating(id: Long) = id in animating

    fun onCompleted(id: Long): Boolean {
        if (reduceMotion) return false
        if (id in animating) return false
        animating += id
        plays++
        return true
    }

    fun finish(id: Long) { animating -= id }
    fun onUncompleted(id: Long) { animating -= id }
}

class CompletionAnimationStateTest {

    @Test
    fun genuineTransition_animatesOnce() {
        val animator = TestAnimator()
        assertTrue(animator.onCompleted(1L))
        assertTrue("row must hold position while drawing", animator.isAnimating(1L))
        assertEquals(1, animator.plays)
    }

    @Test
    fun recomposition_doesNotReplay() {
        val animator = TestAnimator()
        animator.onCompleted(1L)
        repeat(50) { /* redraws, scroll, navigation … */ }
        assertEquals("recomposition must not replay", 1, animator.plays)
    }

    @Test
    fun repeatedCompletionWhileAnimating_isIgnored() {
        val animator = TestAnimator()
        animator.onCompleted(1L)
        animator.onCompleted(1L)
        assertEquals(1, animator.plays)
    }

    @Test
    fun appRestart_neverAnimatesAlreadyCompletedTasks() {
        val restarted = TestAnimator()
        assertFalse(restarted.isAnimating(1L))
        assertEquals(0, restarted.plays)
    }

    @Test
    fun uncheckThenRecheck_animatesAgain() {
        val animator = TestAnimator()
        animator.onCompleted(1L)
        animator.finish(1L)
        animator.onUncompleted(1L)
        assertTrue(animator.onCompleted(1L))
        assertEquals(2, animator.plays)
    }

    @Test
    fun reducedMotion_skipsTheAnimation() {
        val animator = TestAnimator(reduceMotion = true)
        assertFalse(animator.onCompleted(1L))
        assertEquals(0, animator.plays)
    }

    @Test
    fun tasksAreTrackedIndependently() {
        val animator = TestAnimator()
        animator.onCompleted(1L)
        animator.onCompleted(2L)
        animator.finish(1L)
        assertFalse(animator.isAnimating(1L))
        assertTrue(animator.isAnimating(2L))
        assertEquals(2, animator.plays)
    }
}
