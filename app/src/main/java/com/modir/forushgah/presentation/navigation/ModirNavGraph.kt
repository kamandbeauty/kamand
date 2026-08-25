package com.modir.forushgah.presentation.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.modir.forushgah.presentation.categories.CategoryListRoute
import com.modir.forushgah.presentation.customers.CustomerDetailRoute
import com.modir.forushgah.presentation.customers.CustomerFormRoute
import com.modir.forushgah.presentation.customers.CustomerListRoute
import com.modir.forushgah.presentation.dashboard.DashboardRoute
import com.modir.forushgah.presentation.invoice.InvoiceCreateRoute
import com.modir.forushgah.presentation.invoice.InvoiceListRoute
import com.modir.forushgah.presentation.invoice.InvoicePreviewRoute
import com.modir.forushgah.presentation.more.MoreRoute
import com.modir.forushgah.presentation.orders.OrderDetailRoute
import com.modir.forushgah.presentation.orders.OrderFormRoute
import com.modir.forushgah.presentation.returns.ReturnsListRoute
import com.modir.forushgah.presentation.shipment.ShipmentTrackingRoute
import com.modir.forushgah.presentation.products.ProductDetailRoute
import com.modir.forushgah.presentation.products.ProductFormRoute
import com.modir.forushgah.presentation.products.ProductListRoute
import com.modir.forushgah.presentation.stock.StockAdjustmentRoute
import com.modir.forushgah.presentation.suppliers.SupplierDetailRoute
import com.modir.forushgah.presentation.suppliers.SupplierFormRoute
import com.modir.forushgah.presentation.suppliers.SupplierListRoute

/** All non-tab routes (Phase 2 drill-down screens). */
object Routes {
    const val PRODUCT = "product/{productId}"
    const val PRODUCT_FORM = "product_form/{productId?}"
    const val CATEGORIES = "categories"
    const val CUSTOMERS = "customers"
    const val CUSTOMER = "customer/{customerId}"
    const val CUSTOMER_FORM = "customer_form/{customerId?}"
    const val SUPPLIERS = "suppliers"
    const val SUPPLIER = "supplier/{supplierId}"
    const val SUPPLIER_FORM = "supplier_form/{supplierId?}"
    const val STOCK_ADJUSTMENT = "stock_adjustment"
    const val SETTINGS = "settings"
    const val ORDER_FORM = "order_form"
    const val ORDER = "order/{orderId}"
    const val RETURNS = "returns"
    // Phase 3.1 (Rubi invoice experience)
    const val INVOICE_FORM = "invoice_form/{orderId?}"
    const val INVOICE = "invoice/{orderId}"
    const val SHIPMENTS = "shipments" // «کدهای رهگیری ارسال»
}

@Composable
fun ModirNavGraph() {
    val navController = rememberNavController()

    Scaffold(
        bottomBar = { ModirBottomBar(navController) },
    ) { padding ->
        NavHost(
            navController = navController,
            startDestination = BottomNavItem.Home.route,
            modifier = Modifier.padding(padding),
        ) {
            composable(BottomNavItem.Home.route) {
                DashboardRoute(onStartFirstOrder = { navController.navigate(BottomNavItem.Orders.route) })
            }
            composable(BottomNavItem.Orders.route) {
                // Phase 3.1: the orders tab IS the Rubi invoice list (spec §12/§15).
                InvoiceListRoute(
                    onInvoiceClick = { id -> navController.navigate("invoice/$id") },
                    onAddInvoice = { navController.navigate(Routes.INVOICE_FORM) },
                    onReturnsClick = { navController.navigate(Routes.RETURNS) },
                )
            }
            composable(
                route = Routes.INVOICE_FORM,
                arguments = listOf(navArgument("orderId") { type = NavType.LongType; nullable = true }),
            ) {
                InvoiceCreateRoute(
                    onSaved = { id ->
                        // Rubi: pushReplacement to the preview after save.
                        navController.navigate("invoice/$id") {
                            popUpTo(navController.currentDestination?.id ?: 0) { inclusive = true }
                            launchSingleTop = true
                        }
                    },
                    onBack = { navController.popBackStack() },
                )
            }
            composable(
                route = Routes.INVOICE,
                arguments = listOf(navArgument("orderId") { type = NavType.LongType }),
            ) {
                InvoicePreviewRoute(
                    onBack = { navController.popBackStack() },
                    onEdit = { id -> navController.navigate("invoice_form/$id") },
                )
            }
            composable(Routes.ORDER_FORM) {
                OrderFormRoute(
                    onSaved = { navController.popBackStack() },
                    onBack = { navController.popBackStack() },
                )
            }
            composable(
                route = Routes.ORDER,
                arguments = listOf(navArgument("orderId") { type = NavType.LongType }),
            ) { entry ->
                val orderId = entry.arguments?.getLong("orderId") ?: return@composable
                OrderDetailRoute(onBack = { navController.popBackStack() })
            }
            composable(Routes.RETURNS) {
                ReturnsListRoute(
                    onBack = { navController.popBackStack() },
                    onOrderClick = { id -> navController.navigate("order/$id") },
                )
            }
            composable(Routes.SHIPMENTS) {
                ShipmentTrackingRoute(
                    onBack = { navController.popBackStack() },
                    onCustomerEdit = { id -> navController.navigate("customer_form/$id") },
                )
            }
            composable(BottomNavItem.Products.route) {
                ProductListRoute(
                    onProductClick = { id -> navController.navigate("product/$id") },
                    onAddProduct = { navController.navigate(Routes.PRODUCT_FORM) },
                    onCategoriesClick = { navController.navigate(Routes.CATEGORIES) },
                )
            }
            composable(
                route = Routes.PRODUCT,
                arguments = listOf(navArgument("productId") { type = NavType.LongType }),
            ) { entry ->
                val productId = entry.arguments?.getLong("productId") ?: return@composable
                ProductDetailRoute(
                    onBack = { navController.popBackStack() },
                    onEdit = { navController.navigate("product_form/$productId") },
                )
            }
            composable(
                route = Routes.PRODUCT_FORM,
                arguments = listOf(navArgument("productId") { type = NavType.LongType; nullable = true }),
            ) {
                ProductFormRoute(
                    onSaved = { navController.popBackStack() },
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.CATEGORIES) {
                CategoryListRoute(onBack = { navController.popBackStack() })
            }
            composable(Routes.CUSTOMERS) {
                CustomerListRoute(
                    onCustomerClick = { id -> navController.navigate("customer/$id") },
                    onAddCustomer = { navController.navigate(Routes.CUSTOMER_FORM) },
                )
            }
            composable(
                route = Routes.CUSTOMER,
                arguments = listOf(navArgument("customerId") { type = NavType.LongType }),
            ) { entry ->
                val customerId = entry.arguments?.getLong("customerId") ?: return@composable
                CustomerDetailRoute(
                    onBack = { navController.popBackStack() },
                    onEdit = { navController.navigate("customer_form/$customerId") },
                )
            }
            composable(
                route = Routes.CUSTOMER_FORM,
                arguments = listOf(navArgument("customerId") { type = NavType.LongType; nullable = true }),
            ) {
                CustomerFormRoute(
                    onSaved = { navController.popBackStack() },
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.SUPPLIERS) {
                SupplierListRoute(
                    onSupplierClick = { id -> navController.navigate("supplier/$id") },
                    onAddSupplier = { navController.navigate(Routes.SUPPLIER_FORM) },
                )
            }
            composable(
                route = Routes.SUPPLIER,
                arguments = listOf(navArgument("supplierId") { type = NavType.LongType }),
            ) { entry ->
                val supplierId = entry.arguments?.getLong("supplierId") ?: return@composable
                SupplierDetailRoute(
                    onBack = { navController.popBackStack() },
                    onEdit = { navController.navigate("supplier_form/$supplierId") },
                    onArchived = { navController.popBackStack() },
                )
            }
            composable(
                route = Routes.SUPPLIER_FORM,
                arguments = listOf(navArgument("supplierId") { type = NavType.LongType; nullable = true }),
            ) {
                SupplierFormRoute(
                    onSaved = { navController.popBackStack() },
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.STOCK_ADJUSTMENT) {
                StockAdjustmentRoute(onBack = { navController.popBackStack() })
            }
            composable(BottomNavItem.More.route) {
                MoreRoute(
                    onCustomersClick = { navController.navigate(Routes.CUSTOMERS) },
                    onSuppliersClick = { navController.navigate(Routes.SUPPLIERS) },
                    onStockAdjustmentClick = { navController.navigate(Routes.STOCK_ADJUSTMENT) },
                    onShipmentsClick = { navController.navigate(Routes.SHIPMENTS) },
                    onSettingsClick = { navController.navigate(Routes.SETTINGS) },
                )
            }
            composable(BottomNavItem.Finance.route) {
                PhaseUpcomingScreen(title = "مالی", note = "مطالبات، بدهی‌ها و گزارش‌های مالی در فاز بعدی تکمیل می‌شود")
            }
            composable(Routes.SETTINGS) {
                PhaseUpcomingScreen(title = "تنظیمات", note = "تنظیمات فروشگاه در فاز بعدی تکمیل می‌شود")
            }
        }
    }
}

@Composable
private fun ModirBottomBar(navController: NavHostController) {
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route

    NavigationBar {
        BottomNavItem.entries.forEach { item ->
            val selected = currentRoute?.let { routeBelongsToTab(it, item) } == true
            NavigationBarItem(
                selected = selected,
                onClick = {
                    navController.navigate(item.route) {
                        popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                        launchSingleTop = true
                        restoreState = true
                    }
                },
                icon = { Icon(item.icon, contentDescription = item.label) },
                label = { Text(item.label) },
            )
        }
    }
}

/** Keeps the owning bottom tab highlighted while the user is inside a
 * drill-down screen (e.g. the «محصولات» tab stays active on product detail,
 * categories, and customer/supplier screens under «بیشتر»). */
private fun routeBelongsToTab(route: String, tab: BottomNavItem): Boolean = when (tab) {
    BottomNavItem.Home -> route == tab.route
    BottomNavItem.Orders -> route == tab.route
    // "product" prefix matches "products", "product/123" and "product_form…".
    BottomNavItem.Products -> route.startsWith("product") || route == Routes.CATEGORIES
    BottomNavItem.Orders -> route == tab.route ||
        route.startsWith("order") ||
        route.startsWith("invoice") ||
        route == Routes.RETURNS
    BottomNavItem.Finance -> route == tab.route
    BottomNavItem.More -> route == tab.route ||
        route.startsWith("customer") ||
        route.startsWith("supplier") ||
        route == Routes.STOCK_ADJUSTMENT ||
        route == Routes.SETTINGS
}
