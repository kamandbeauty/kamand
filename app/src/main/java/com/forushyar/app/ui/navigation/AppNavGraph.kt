package com.forushyar.app.ui.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.forushyar.app.ui.customers.CustomerDetailScreen
import com.forushyar.app.ui.customers.CustomerFormScreen
import com.forushyar.app.ui.customers.CustomersScreen
import com.forushyar.app.ui.home.HomeScreen
import com.forushyar.app.ui.orders.OrderDetailScreen
import com.forushyar.app.ui.orders.OrderFormScreen
import com.forushyar.app.ui.orders.OrdersScreen
import com.forushyar.app.ui.products.ProductDetailScreen
import com.forushyar.app.ui.products.ProductFormScreen
import com.forushyar.app.ui.products.ProductsScreen
import com.forushyar.app.ui.settings.SettingsScreen

private object OrderRoutes {
    const val ADD = "orders/add"
    const val DETAIL = "orders/{orderId}"

    fun detail(orderId: Long) = "orders/$orderId"
}

private object CustomerRoutes {
    const val ADD = "customers/add"
    const val DETAIL = "customers/{customerId}"
    const val EDIT = "customers/{customerId}/edit"

    fun detail(customerId: Long) = "customers/$customerId"
    fun edit(customerId: Long) = "customers/$customerId/edit"
}

private object ProductRoutes {
    const val ADD = "products/add"
    const val DETAIL = "products/{productId}"
    const val EDIT = "products/{productId}/edit"

    fun detail(productId: Long) = "products/$productId"
    fun edit(productId: Long) = "products/$productId/edit"
}

/**
 * گراف ناوبری اصلی برنامه با Bottom Navigation پنج‌تبی.
 */
@Composable
fun AppNavGraph() {
    val navController = rememberNavController()
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route

    Scaffold(
        bottomBar = {
            NavigationBar {
                BottomNavItem.entries.forEach { item ->
                    val selected = currentRoute == item.route || when (item) {
                        BottomNavItem.Orders -> currentRoute?.startsWith("orders/") == true
                        BottomNavItem.Customers -> currentRoute?.startsWith("customers/") == true
                        BottomNavItem.Products -> currentRoute?.startsWith("products/") == true
                        else -> false
                    }
                    NavigationBarItem(
                        selected = selected,
                        onClick = {
                            navController.navigate(item.route) {
                                popUpTo(navController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = {
                            Icon(
                                imageVector = if (selected) item.selectedIcon else item.icon,
                                contentDescription = null
                            )
                        },
                        label = { Text(stringResource(item.labelRes)) }
                    )
                }
            }
        }
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = BottomNavItem.Home.route,
            modifier = Modifier.padding(innerPadding)
        ) {
            composable(BottomNavItem.Home.route) { HomeScreen() }

            // --- مسیرهای اصلی و صفحه‌های هر بخش ---
            composable(BottomNavItem.Orders.route) {
                OrdersScreen(
                    onAddOrder = { navController.navigate(OrderRoutes.ADD) },
                    onOrderClick = { id -> navController.navigate(OrderRoutes.detail(id)) }
                )
            }
            composable(OrderRoutes.ADD) {
                OrderFormScreen(
                    onBack = { navController.popBackStack() },
                    onSaved = { id ->
                        navController.popBackStack()
                        navController.navigate(OrderRoutes.detail(id))
                    }
                )
            }
            composable(
                route = OrderRoutes.DETAIL,
                arguments = listOf(navArgument("orderId") { type = NavType.LongType })
            ) {
                OrderDetailScreen(onBack = { navController.popBackStack() })
            }
            composable(BottomNavItem.Customers.route) {
                CustomersScreen(
                    onAddCustomer = { navController.navigate(CustomerRoutes.ADD) },
                    onCustomerClick = { id -> navController.navigate(CustomerRoutes.detail(id)) }
                )
            }
            composable(CustomerRoutes.ADD) {
                CustomerFormScreen(onBack = { navController.popBackStack() })
            }
            composable(
                route = CustomerRoutes.DETAIL,
                arguments = listOf(navArgument("customerId") { type = NavType.LongType })
            ) {
                CustomerDetailScreen(
                    onBack = { navController.popBackStack() },
                    onEdit = { id -> navController.navigate(CustomerRoutes.edit(id)) }
                )
            }
            composable(
                route = CustomerRoutes.EDIT,
                arguments = listOf(navArgument("customerId") { type = NavType.LongType })
            ) {
                CustomerFormScreen(onBack = { navController.popBackStack() })
            }
            composable(BottomNavItem.Products.route) {
                ProductsScreen(
                    onAddProduct = { navController.navigate(ProductRoutes.ADD) },
                    onProductClick = { id -> navController.navigate(ProductRoutes.detail(id)) }
                )
            }
            composable(ProductRoutes.ADD) {
                ProductFormScreen(onBack = { navController.popBackStack() })
            }
            composable(
                route = ProductRoutes.DETAIL,
                arguments = listOf(navArgument("productId") { type = NavType.LongType })
            ) {
                ProductDetailScreen(
                    onBack = { navController.popBackStack() },
                    onEdit = { id -> navController.navigate(ProductRoutes.edit(id)) }
                )
            }
            composable(
                route = ProductRoutes.EDIT,
                arguments = listOf(navArgument("productId") { type = NavType.LongType })
            ) {
                ProductFormScreen(onBack = { navController.popBackStack() })
            }
            composable(BottomNavItem.Settings.route) { SettingsScreen() }
        }
    }
}
