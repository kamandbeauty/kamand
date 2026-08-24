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
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.modir.forushgah.presentation.dashboard.DashboardRoute

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
                PhaseUpcomingScreen(title = "سفارش‌ها", note = "ثبت و مدیریت سفارش‌ها در فاز بعدی تکمیل می‌شود")
            }
            composable(BottomNavItem.Products.route) {
                PhaseUpcomingScreen(title = "محصولات", note = "مدیریت محصولات و موجودی در فاز بعدی تکمیل می‌شود")
            }
            composable(BottomNavItem.Finance.route) {
                PhaseUpcomingScreen(title = "مالی", note = "مطالبات، بدهی‌ها و گزارش‌های مالی در فاز بعدی تکمیل می‌شود")
            }
            composable(BottomNavItem.More.route) {
                PhaseUpcomingScreen(title = "بیشتر", note = "تنظیمات، تأمین‌کنندگان و مشتریان در فاز بعدی تکمیل می‌شود")
            }
        }
    }
}

@Composable
private fun ModirBottomBar(navController: NavHostController) {
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = backStackEntry?.destination

    NavigationBar {
        BottomNavItem.entries.forEach { item ->
            val selected = currentDestination?.hierarchy?.any { it.route == item.route } == true
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
