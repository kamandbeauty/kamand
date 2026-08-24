package com.modir.forushgah.presentation.more

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowLeft
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.material3.Card
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp

/**
 * The «بیشتر» bottom tab (Phase 2): entry point to customer/supplier
 * management plus the (still upcoming) settings screen.
 */
@Composable
fun MoreRoute(
    onCustomersClick: () -> Unit,
    onSuppliersClick: () -> Unit,
    onStockAdjustmentClick: () -> Unit,
    onSettingsClick: () -> Unit,
) {
    Scaffold(topBar = { TopAppBar(title = { Text("بیشتر") }) }) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            MoreMenuRow(
                icon = Icons.Filled.People,
                title = "مشتریان",
                subtitle = "مدیریت مشتریان و پیگیری سفارش‌های آن‌ها",
                onClick = onCustomersClick,
            )
            MoreMenuRow(
                icon = Icons.Filled.LocalShipping,
                title = "تأمین‌کنندگان",
                subtitle = "مدیریت تأمین‌کنندگان و خرید کالا",
                onClick = onSuppliersClick,
            )
            MoreMenuRow(
                icon = Icons.Filled.SwapVert,
                title = "تنظیم موجودی",
                subtitle = "تغییر دستی موجودی محصول با ثبت خودکار گردش",
                onClick = onStockAdjustmentClick,
            )
            MoreMenuRow(
                icon = Icons.Filled.Settings,
                title = "تنظیمات",
                subtitle = "در فاز بعدی تکمیل می‌شود",
                onClick = onSettingsClick,
            )
        }
    }
}

@Composable
private fun MoreMenuRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
    onClick: () -> Unit,
) {
    Card(modifier = Modifier.fillMaxWidth().clickable(onClick = onClick)) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.titleMedium)
                Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            // In RTL the "forward" chevron points left.
            Icon(
                Icons.Filled.KeyboardArrowLeft,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
