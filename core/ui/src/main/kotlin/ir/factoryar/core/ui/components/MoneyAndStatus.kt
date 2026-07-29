package ir.factoryar.core.ui.components

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import ir.factoryar.core.common.util.PersianFormatter.formatMoney
import ir.factoryar.core.common.util.PersianFormatter.formatMoneyWithUnit
import ir.factoryar.core.domain.model.Invoice
import ir.factoryar.core.domain.model.PaymentStatus
import ir.factoryar.core.ui.theme.LocalCurrencyUnit

/** نمایش مبلغ با واحد پول فعلی و ارقام فارسی */
@Composable
fun MoneyText(
    amount: Long,
    modifier: Modifier = Modifier,
    style: TextStyle = MaterialTheme.typography.bodyMedium,
    color: Color = Color.Unspecified,
    withUnit: Boolean = true,
) {
    val unit = LocalCurrencyUnit.current
    Text(
        text = if (withUnit) formatMoneyWithUnit(amount, unit) else formatMoney(amount),
        modifier = modifier,
        style = style,
        color = color,
    )
}

@Composable
fun PaymentStatusChip(invoice: Invoice, modifier: Modifier = Modifier) {
    val (label, bg, fg) = when {
        invoice.isOverdue -> Triple(
            "معوق",
            MaterialTheme.colorScheme.errorContainer,
            MaterialTheme.colorScheme.onErrorContainer,
        )
        invoice.status == PaymentStatus.PAID -> Triple(
            PaymentStatus.PAID.faName,
            Color(0xFFDCF5E3),
            Color(0xFF14532D),
        )
        invoice.status == PaymentStatus.PARTIAL -> Triple(
            PaymentStatus.PARTIAL.faName,
            Color(0xFFFFF3D6),
            Color(0xFF7A4E00),
        )
        else -> Triple(
            PaymentStatus.UNPAID.faName,
            MaterialTheme.colorScheme.surfaceVariant,
            MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
    Surface(modifier = modifier, shape = MaterialTheme.shapes.small, color = bg) {
        Text(
            label,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
            style = MaterialTheme.typography.labelSmall,
            color = fg,
        )
    }
}
