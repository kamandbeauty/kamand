package com.modir.forushgah.presentation.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountBalanceWallet
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.ui.graphics.vector.ImageVector

enum class BottomNavItem(val route: String, val label: String, val icon: ImageVector) {
    Home(route = "home", label = "خانه", icon = Icons.Filled.Home),
    Orders(route = "orders", label = "سفارش‌ها", icon = Icons.Filled.ShoppingCart),
    Products(route = "products", label = "محصولات", icon = Icons.Filled.Inventory2),
    Finance(route = "finance", label = "مالی", icon = Icons.Filled.AccountBalanceWallet),
    More(route = "more", label = "بیشتر", icon = Icons.Filled.MoreHoriz),
}
