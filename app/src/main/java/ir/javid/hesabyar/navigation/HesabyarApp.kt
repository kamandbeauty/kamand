package ir.javid.hesabyar.navigation

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import ir.javid.hesabyar.core.ui.LocalOpenNavigation
import ir.javid.hesabyar.feature.accounting.AccountingScreen
import ir.javid.hesabyar.feature.cash.CashScreen
import ir.javid.hesabyar.feature.dashboard.DashboardScreen
import ir.javid.hesabyar.feature.invoices.InvoicesScreen
import ir.javid.hesabyar.feature.parties.PartiesScreen
import ir.javid.hesabyar.feature.products.ProductsScreen
import ir.javid.hesabyar.feature.reports.ReportsScreen
import ir.javid.hesabyar.feature.settings.SettingsScreen
import ir.javid.hesabyar.core.model.InvoiceKind
import kotlinx.coroutines.launch

private data class Destination(val route: String, val label: String, val icon: androidx.compose.ui.graphics.vector.ImageVector)
private val destinations = listOf(
    Destination("dashboard", "خانه", Icons.Outlined.Home),
    Destination("sales", "فروش", Icons.Outlined.PointOfSale),
    Destination("purchases", "خرید", Icons.Outlined.ShoppingCart),
    Destination("products", "کالاها", Icons.Outlined.Inventory2),
    Destination("parties", "اشخاص", Icons.Outlined.PeopleAlt),
    Destination("cash", "دریافت و پرداخت", Icons.Outlined.AccountBalanceWallet),
    Destination("accounting", "حسابداری", Icons.Outlined.AccountBalance),
    Destination("reports", "گزارش‌ها", Icons.Outlined.Assessment),
    Destination("settings", "تنظیمات", Icons.Outlined.Settings)
)

@Composable
fun HesabyarApp(onRestoreCompleted: () -> Unit) {
    val navController = rememberNavController()
    val drawerState = rememberDrawerState(DrawerValue.Closed)
    val scope = rememberCoroutineScope()
    val current = navController.currentBackStackEntryAsState().value?.destination?.route
    ModalNavigationDrawer(
        drawerState = drawerState,
        drawerContent = {
            ModalDrawerSheet(Modifier.widthIn(max = 320.dp)) {
                Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text("حسابیار جاوید", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                    Text("حسابداری ساده برای کسب‌وکار شما", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                HorizontalDivider()
                Spacer(Modifier.height(8.dp))
                destinations.forEach { item ->
                    NavigationDrawerItem(label = { Text(item.label) }, selected = current == item.route, icon = { Icon(item.icon, null) }, modifier = Modifier.padding(NavigationDrawerItemDefaults.ItemPadding), onClick = {
                        navController.navigate(item.route) { popUpTo("dashboard") { saveState = true }; launchSingleTop = true; restoreState = true }
                        scope.launch { drawerState.close() }
                    })
                }
                Spacer(Modifier.weight(1f))
                Text("نسخه ۱.۰.۰ • آفلاین", modifier = Modifier.padding(20.dp), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    ) {
        CompositionLocalProvider(LocalOpenNavigation provides { scope.launch { drawerState.open() } }) {
            NavHost(navController, startDestination = "dashboard", modifier = Modifier.fillMaxSize()) {
                composable("dashboard") { DashboardScreen(onOpenProducts = { navController.navigate("products") }) }
                composable("sales") { InvoicesScreen(InvoiceKind.SALE) }
                composable("purchases") { InvoicesScreen(InvoiceKind.PURCHASE) }
                composable("products") { ProductsScreen() }
                composable("parties") { PartiesScreen() }
                composable("cash") { CashScreen() }
                composable("accounting") { AccountingScreen() }
                composable("reports") { ReportsScreen() }
                composable("settings") { SettingsScreen(onRestoreCompleted) }
            }
        }
    }
}
