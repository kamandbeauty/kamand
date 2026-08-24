package com.modir.forushgah.core.designsystem.component

import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import com.modir.forushgah.core.designsystem.theme.LocalSemanticColors

enum class StockLevel { NORMAL, LOW, OUT_OF_STOCK }

fun stockLevelOf(stockQuantity: Int, minimumStock: Int): StockLevel = when {
    stockQuantity <= 0 -> StockLevel.OUT_OF_STOCK
    stockQuantity <= minimumStock -> StockLevel.LOW
    else -> StockLevel.NORMAL
}

/** A small, subtle stock indicator — deliberately minimal per spec §11
 * ("do not overcrowd the row"). Only shown when it's not the normal case,
 * unless [alwaysShow] is set (used on the product detail screen). */
@Composable
fun StockBadge(level: StockLevel, alwaysShow: Boolean = false) {
    if (level == StockLevel.NORMAL && !alwaysShow) return

    val semantic = LocalSemanticColors.current
    val (label, color, container) = when (level) {
        StockLevel.NORMAL -> Triple("موجود", semantic.success, semantic.successContainer)
        StockLevel.LOW -> Triple("کم", semantic.warning, semantic.warningContainer)
        StockLevel.OUT_OF_STOCK -> Triple("ناموجود", MaterialTheme.colorScheme.error, MaterialTheme.colorScheme.errorContainer)
    }

    Surface(shape = RoundedCornerShape(8.dp), color = container) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = color,
            modifier = androidx.compose.ui.Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
        )
    }
}
