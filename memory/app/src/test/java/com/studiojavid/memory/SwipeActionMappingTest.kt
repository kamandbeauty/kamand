package com.studiojavid.memory

import com.studiojavid.memory.ui.components.SwipeDirection
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Swipe direction contract for task rows.
 *
 * material3's SwipeToDismissBox mirrors its *anchors* under RTL, not the drag:
 * the gesture is read with reverseDirection = false and the row is placed at the
 * raw offset, so a physical right-swipe is always a positive offset. Only the
 * enum labels swap sides — under RTL StartToEnd sits at -width and EndToStart at
 * +width.
 *
 * So the rule the UI must follow is: decide from the *movement*, never from the
 * enum name. Right = done, left = delete, in both locales.
 */
private const val LTR = false
private const val RTL = true

private fun action(startToEnd: Boolean, rtl: Boolean): String =
    if (SwipeDirection.movedRight(startToEnd, rtl)) "done" else "delete"

/** The hint must sit in the gap the row uncovered, derived from the offset sign. */
private fun gapOnLeft(offsetPx: Float): Boolean = offsetPx > 0f

private fun label(offsetPx: Float): String = if (gapOnLeft(offsetPx)) "done" else "delete"

class SwipeActionMappingTest {

    @Test
    fun swipeRightCompletes_inBothLayoutDirections() {
        // LTR: moving right settles on StartToEnd. RTL: it settles on EndToStart.
        assertEquals("done", action(startToEnd = true, rtl = LTR))
        assertEquals("done", action(startToEnd = false, rtl = RTL))
    }

    @Test
    fun swipeLeftDeletes_inBothLayoutDirections() {
        assertEquals("delete", action(startToEnd = false, rtl = LTR))
        assertEquals("delete", action(startToEnd = true, rtl = RTL))
    }

    @Test
    fun rtlInvertsTheEnumButNotTheGesture() {
        // The regression: reading the enum directly flipped the action in Persian.
        listOf(true, false).forEach { startToEnd ->
            assertEquals(
                "the same enum value must mean opposite movement across locales",
                SwipeDirection.movedRight(startToEnd, LTR),
                !SwipeDirection.movedRight(startToEnd, RTL)
            )
        }
    }

    @Test
    fun labelAlwaysMatchesTheAction() {
        // Positive offset = moved right = done; the hint reads from the same sign
        // the action does, so the two cannot disagree.
        assertEquals(action(startToEnd = true, rtl = LTR), label(120f))
        assertEquals(action(startToEnd = false, rtl = LTR), label(-120f))
        assertEquals(action(startToEnd = false, rtl = RTL), label(120f))
        assertEquals(action(startToEnd = true, rtl = RTL), label(-120f))
    }

    @Test
    fun hintSitsInTheGapThatOpened() {
        assertTrue("card moved right -> gap on the left", gapOnLeft(80f))
        assertFalse("card moved left -> gap on the right", gapOnLeft(-80f))
    }
}
