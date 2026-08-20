package com.studiojavid.memory.data.repo

import com.studiojavid.memory.R
import com.studiojavid.memory.data.local.CategoryEntity

/**
 * Built-in categories. Their display name is resolved from resources through
 * [labelRes] so they follow the app language; the stored `name` is only a
 * fallback used by backups and by custom categories.
 */
object DefaultCategories {

    const val PERSONAL = "personal"
    const val WORK = "work"
    const val SHOPPING = "shopping"
    const val HEALTH = "health"
    const val STUDY = "study"
    const val OTHER = "other"

    // Palette kept in sync with the design tokens in ui/theme/Color.kt
    private const val CORAL = 0xFFFF6B6B.toInt()
    private const val PURPLE = 0xFF7C5CFF.toInt()
    private const val ORANGE = 0xFFFF9F45.toInt()
    private const val MINT = 0xFF2ECC9B.toInt()
    private const val TURQUOISE = 0xFF31C8E6.toInt()
    private const val PINK = 0xFFFF7EB6.toInt()
    private const val BLUE = 0xFF4C8DF6.toInt()

    fun seed(): List<CategoryEntity> = listOf(
        CategoryEntity(name = "شخصی", icon = "🌿", color = PURPLE, builtInKey = PERSONAL, createdAt = 1),
        CategoryEntity(name = "کار", icon = "💼", color = BLUE, builtInKey = WORK, createdAt = 2),
        CategoryEntity(name = "خرید", icon = "🛒", color = ORANGE, builtInKey = SHOPPING, createdAt = 3),
        CategoryEntity(name = "سلامتی", icon = "💚", color = MINT, builtInKey = HEALTH, createdAt = 4),
        CategoryEntity(name = "مطالعه", icon = "📚", color = PINK, builtInKey = STUDY, createdAt = 5),
        CategoryEntity(name = "سایر", icon = "✨", color = TURQUOISE, builtInKey = OTHER, createdAt = 6)
    )

    fun labelRes(key: String): Int? = when (key) {
        PERSONAL -> R.string.category_personal
        WORK -> R.string.category_work
        SHOPPING -> R.string.category_shopping
        HEALTH -> R.string.category_health
        STUDY -> R.string.category_study
        OTHER -> R.string.category_other
        else -> null
    }

    /** Colors offered when the user creates a category. */
    val palette: List<Int> = listOf(
        CORAL, ORANGE, 0xFFFFC93C.toInt(), MINT, TURQUOISE, BLUE, PURPLE, PINK
    )

    val emojis: List<String> = listOf(
        "🌿", "💼", "🛒", "💚", "📚", "✨", "🏃", "🎨", "🍳", "✈️", "🎵", "💡", "🐾", "🏠", "☕", "🎯"
    )
}
