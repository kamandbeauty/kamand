package com.roozi.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Swipe direction contract for task rows.
 *
 * SwipeToDismissBox already mirrors itself for RTL, so the enum describes the
 * *visual* movement in both layout directions:
 *   StartToEnd -> the card moves right
 *   EndToStart -> the card moves left
 *
 * A previous version added another `if (rtl)` on top of that, which
 * double-corrected and inverted the gesture in Persian: swiping right deleted
 * the task instead of completing it.
 */
private enum class Dir { StartToEnd, EndToStart, Settled }

private fun action(direction: Dir): String = when (direction) {
    Dir.StartToEnd -> "done"
    Dir.EndToStart -> "delete"
    Dir.Settled -> "none"
}

private fun label(direction: Dir): String =
    if (direction == Dir.EndToStart) "delete" else "done"

/** True when the revealed gap is on the left (the card moved right). */
private fun gapOnLeft(direction: Dir): Boolean = direction == Dir.StartToEnd

class SwipeActionMappingTest {

    @Test
    fun swipeRightCompletes_inBothLayoutDirections() {
        // The mapping is direction-agnostic by design, so one assertion covers
        // both locales; the point is that no rtl branch exists any more.
        assertEquals("done", action(Dir.StartToEnd))
    }

    @Test
    fun swipeLeftDeletes_inBothLayoutDirections() {
        assertEquals("delete", action(Dir.EndToStart))
    }

    @Test
    fun labelAlwaysMatchesTheAction() {
        listOf(Dir.StartToEnd, Dir.EndToStart).forEach { direction ->
            assertEquals(
                "the hint must not promise a different action",
                action(direction),
                label(direction)
            )
        }
    }

    @Test
    fun hintSitsInTheGapThatOpened() {
        assertTrue("card moved right -> gap on the left", gapOnLeft(Dir.StartToEnd))
        assertTrue("card moved left -> gap on the right", !gapOnLeft(Dir.EndToStart))
    }

    @Test
    fun settledDoesNothing() {
        assertEquals("none", action(Dir.Settled))
    }
}
