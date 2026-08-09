package ir.factoryar.app

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Receipt
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import ir.factoryar.app.navigation.Routes
import ir.factoryar.core.domain.model.InvoiceType
import ir.factoryar.feature.customers.CustomerDetailScreen
import ir.factoryar.feature.customers.CustomersScreen
import ir.factoryar.feature.customers.DebtorsScreen
import ir.factoryar.feature.dashboard.DashboardScreen
import ir.factoryar.feature.expenses.ExpensesScreen
import ir.factoryar.feature.products.ProductEditScreen
import ir.factoryar.feature.products.ProductsScreen
import ir.factoryar.feature.invoices.InvoiceDetailScreen
import ir.factoryar.feature.invoices.InvoiceEditScreen
import ir.factoryar.feature.invoices.InvoicesScreen
import ir.factoryar.feature.invoices.RecurringScreen
import ir.factoryar.feature.reports.ReportsScreen
import ir.factoryar.feature.settings.PremiumScreen
import ir.factoryar.feature.settings.SettingsScreen

private data class BottomTab(val route: String, val label: String, val icon: ImageVector)

private val bottomTabs = listOf(
    BottomTab(Routes.DASHBOARD, "داشبورد", Icons.Filled.Home),
    BottomTab(Routes.INVOICES, "فاکتورها", Icons.Filled.Receipt),
    BottomTab(Routes.CUSTOMERS, "مشتریان", Icons.Filled.People),
    BottomTab(Routes.REPORTS, "گزارش‌ها", Icons.Filled.BarChart),
    BottomTab(Routes.SETTINGS, "تنظیمات", Icons.Filled.Settings),
)

@Composable
fun MainScaffold(initialRoute: String? = null) {
    val navController = rememberNavController()
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route
    val showBottomBar = currentRoute in bottomTabs.map { it.route }

    // ناوبری از نوتیفیکیشن و ویجت صفحه اصلی
    LaunchedEffect(initialRoute) {
        when {
            initialRoute == null -> Unit
            // میان‌بر ویجت: مستقیم فرم فاکتور جدید باز می‌شود
            initialRoute == "new_invoice" ->
                navController.navigate(Routes.invoiceEdit(type = InvoiceType.SALE)) { launchSingleTop = true }
            initialRoute == Routes.DEBTORS ->
                navController.navigate(Routes.DEBTORS) { launchSingleTop = true }
            initialRoute == Routes.PRODUCTS ->
                navController.navigate(Routes.PRODUCTS) { launchSingleTop = true }
            bottomTabs.any { it.route == initialRoute } ->
                navController.navigate(initialRoute) { launchSingleTop = true }
        }
    }

    Scaffold(
        bottomBar = {
            if (showBottomBar) {
                NavigationBar {
                    bottomTabs.forEach { tab ->
                        NavigationBarItem(
                            selected = currentRoute == tab.route,
                            onClick = {
                                navController.navigate(tab.route) {
                                    popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = { Icon(tab.icon, contentDescription = tab.label) },
                            label = { Text(tab.label) },
                        )
                    }
                }
            }
        },
    ) { innerPadding ->
        FyNavHost(navController = navController, modifier = Modifier.padding(innerPadding))
    }
}

@Composable
private fun FyNavHost(navController: NavHostController, modifier: Modifier = Modifier) {
    NavHost(
        navController = navController,
        startDestination = Routes.DASHBOARD,
        modifier = modifier,
    ) {
        composable(Routes.DASHBOARD) {
            DashboardScreen(
                onNewInvoice = { navController.navigate(Routes.invoiceEdit(type = InvoiceType.SALE)) },
                onNewCustomer = { navController.navigate(Routes.CUSTOMERS) },
                onInvoiceClick = { navController.navigate(Routes.invoiceDetail(it)) },
                onCustomerClick = { navController.navigate(Routes.customerDetail(it)) },
                onSeeAllInvoices = { navController.navigate(Routes.INVOICES) },
                onOpenProducts = { navController.navigate(Routes.PRODUCTS) },
                onOpenExpenses = { navController.navigate(Routes.EXPENSES) },
                onOpenDebtors = { navController.navigate(Routes.DEBTORS) },
            )
        }

        composable(Routes.INVOICES) {
            InvoicesScreen(
                onInvoiceClick = { navController.navigate(Routes.invoiceDetail(it)) },
                onNewInvoice = { type -> navController.navigate(Routes.invoiceEdit(type = type)) },
                onOpenRecurring = { navController.navigate(Routes.RECURRING) },
            )
        }

        composable(Routes.CUSTOMERS) {
            CustomersScreen(
                onCustomerClick = { navController.navigate(Routes.customerDetail(it)) },
                onOpenDebtors = { navController.navigate(Routes.DEBTORS) },
            )
        }

        composable(Routes.DEBTORS) {
            DebtorsScreen(
                onBack = { navController.popBackStack() },
                onCustomerClick = { navController.navigate(Routes.customerDetail(it)) },
            )
        }

        composable(Routes.PRODUCTS) {
            ProductsScreen(
                onBack = { navController.popBackStack() },
                onProductClick = { navController.navigate(Routes.productEdit(productId = it)) },
                onNewProduct = { barcode -> navController.navigate(Routes.productEdit(barcode = barcode)) },
            )
        }

        composable(
            route = Routes.PRODUCT_EDIT,
            arguments = listOf(
                navArgument("productId") { type = NavType.LongType; defaultValue = -1L },
                navArgument("barcode") { type = NavType.StringType; defaultValue = "" },
            ),
        ) {
            ProductEditScreen(
                onBack = { navController.popBackStack() },
                onSaved = { navController.popBackStack() },
            )
        }

        composable(Routes.EXPENSES) {
            ExpensesScreen(onBack = { navController.popBackStack() })
        }

        composable(Routes.REPORTS) {
            ReportsScreen(
                onGoPremium = { navController.navigate(Routes.PREMIUM) },
                onOpenExpenses = { navController.navigate(Routes.EXPENSES) },
            )
        }

        composable(Routes.SETTINGS) {
            SettingsScreen(
                onGoPremium = { navController.navigate(Routes.PREMIUM) },
                onOpenProducts = { navController.navigate(Routes.PRODUCTS) },
                onOpenExpenses = { navController.navigate(Routes.EXPENSES) },
            )
        }

        composable(Routes.RECURRING) {
            RecurringScreen(onBack = { navController.popBackStack() })
        }

        composable(Routes.PREMIUM) {
            PremiumScreen(onBack = { navController.popBackStack() })
        }

        composable(
            route = Routes.INVOICE_EDIT,
            arguments = listOf(
                navArgument("invoiceId") { type = NavType.LongType; defaultValue = -1L },
                navArgument("type") { type = NavType.StringType; defaultValue = InvoiceType.SALE.name },
            ),
        ) {
            InvoiceEditScreen(
                onBack = { navController.popBackStack() },
                onSaved = { id ->
                    navController.navigate(Routes.invoiceDetail(id)) {
                        popUpTo(Routes.INVOICES) { inclusive = false }
                    }
                },
            )
        }

        composable(
            route = Routes.INVOICE_DETAIL,
            arguments = listOf(navArgument("invoiceId") { type = NavType.LongType }),
        ) {
            InvoiceDetailScreen(
                onBack = { navController.popBackStack() },
                onEdit = { id -> navController.navigate(Routes.invoiceEdit(invoiceId = id)) },
            )
        }

        composable(
            route = Routes.CUSTOMER_DETAIL,
            arguments = listOf(navArgument("customerId") { type = NavType.LongType }),
        ) {
            CustomerDetailScreen(
                onBack = { navController.popBackStack() },
                onInvoiceClick = { navController.navigate(Routes.invoiceDetail(it)) },
                onNewInvoiceForCustomer = { navController.navigate(Routes.invoiceEdit(type = InvoiceType.SALE)) },
            )
        }
    }
}
