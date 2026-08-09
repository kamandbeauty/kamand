package com.forushyar.app.ui.navigation

import androidx.annotation.StringRes
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home as HomeFilled
import androidx.compose.material.icons.filled.Person as PersonFilled
import androidx.compose.material.icons.filled.ReceiptLong as ReceiptLongFilled
import androidx.compose.material.icons.filled.Settings as SettingsFilled
import androidx.compose.material.icons.filled.ShoppingBag as ShoppingBagFilled
import androidx.compose.material.icons.outlined.Home as HomeOutlined
import androidx.compose.material.icons.outlined.Person as PersonOutlined
import androidx.compose.material.icons.outlined.ReceiptLong as ReceiptLongOutlined
import androidx.compose.material.icons.outlined.Settings as SettingsOutlined
import androidx.compose.material.icons.outlined.ShoppingBag as ShoppingBagOutlined
import androidx.compose.ui.graphics.vector.ImageVector
import com.forushyar.app.R

/**
 * تب‌های Bottom Navigation
 */
enum class BottomNavItem(
    val route: String,
    @StringRes val labelRes: Int,
    val icon: ImageVector,
    val selectedIcon: ImageVector
) {
    Home(
        route = "home",
        labelRes = R.string.tab_home,
        icon = Icons.Outlined.HomeOutlined,
        selectedIcon = Icons.Filled.HomeFilled
    ),
    Orders(
        route = "orders",
        labelRes = R.string.tab_orders,
        icon = Icons.Outlined.ReceiptLongOutlined,
        selectedIcon = Icons.Filled.ReceiptLongFilled
    ),
    Customers(
        route = "customers",
        labelRes = R.string.tab_customers,
        icon = Icons.Outlined.PersonOutlined,
        selectedIcon = Icons.Filled.PersonFilled
    ),
    Products(
        route = "products",
        labelRes = R.string.tab_products,
        icon = Icons.Outlined.ShoppingBagOutlined,
        selectedIcon = Icons.Filled.ShoppingBagFilled
    ),
    Settings(
        route = "settings",
        labelRes = R.string.tab_settings,
        icon = Icons.Outlined.SettingsOutlined,
        selectedIcon = Icons.Filled.SettingsFilled
    )
}
