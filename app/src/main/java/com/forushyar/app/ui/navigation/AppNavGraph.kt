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
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.forushyar.app.ui.common.PlaceholderScreen
import com.forushyar.app.ui.home.HomeScreen

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
                    val selected = currentRoute == item.route
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

            // --- صفحه‌های نسخه‌های بعدی (در حال حاضر Placeholder) ---
            composable(BottomNavItem.Orders.route) {
                PlaceholderScreen(title = stringResource(BottomNavItem.Orders.labelRes))
            }
            composable(BottomNavItem.Customers.route) {
                PlaceholderScreen(title = stringResource(BottomNavItem.Customers.labelRes))
            }
            composable(BottomNavItem.Products.route) {
                PlaceholderScreen(title = stringResource(BottomNavItem.Products.labelRes))
            }
            composable(BottomNavItem.Settings.route) {
                PlaceholderScreen(title = stringResource(BottomNavItem.Settings.labelRes))
            }
        }
    }
}
