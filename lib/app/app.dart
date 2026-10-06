import 'package:flutter/material.dart';

import '../features/analysis/name_analysis_screen.dart';
import '../features/compatibility/compatibility_screen.dart';
import '../features/home/home_screen.dart';
import '../features/names/name_search_screen.dart';
import '../features/profiles/profiles_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomeScreen(),
      const NameAnalysisScreen(),
      const CompatibilityScreen(),
      const NameSearchScreen(),
      const ProfilesScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'خانه'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'تحلیل'),
          NavigationDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite), label: 'سازگاری'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'نام‌ها'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'پروفایل'),
        ],
      ),
    );
  }
}
