package com.javidstudio.app2.ui.components

/**
 * Translates a settled [androidx.compose.material3.SwipeToDismissBoxValue] into the
 * direction the card physically travelled.
 *
 * material3 1.3.x mirrors the *anchors*, not the gesture: the drag itself runs with
 * `reverseDirection = false` and the content is placed with the absolute
 * `Placeable.place`, so a right-swipe always produces a positive offset. Only the
 * enum labels move — under RTL `StartToEnd` sits at `-width` (left) and `EndToStart`
 * at `+width` (right).
 *
 * Acting on the enum value directly therefore inverts the gesture in Persian, which
 * is why swiping right kept deleting instead of completing. Kept as plain Kotlin so
 * the contract can be unit-tested without a Compose runtime.
 */
internal object SwipeDirection {

    /** True when the row ended up to the right of where it started. */
    fun movedRight(startToEnd: Boolean, rtl: Boolean): Boolean =
        if (rtl) !startToEnd else startToEnd
}
