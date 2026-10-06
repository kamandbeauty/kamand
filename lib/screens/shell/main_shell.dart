import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/star_field.dart';
import '../home/home_screen.dart';
import '../love/love_screen.dart';
import '../profile/profile_screen.dart';
import '../zodiac/zodiac_screen.dart';

/// Bottom-navigation shell: خانه · برج من · عشق · پروفایل (product spec §5).
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  static const _screens = <Widget>[
    HomeScreen(),
    ZodiacScreen(),
    LoveScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Scaffold(
      extendBody: true,
      body: StarField(
        enabled: !reduceMotion,
        child: IndexedStack(
          index: _index,
          children: _screens,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            selectedIcon: const Icon(Icons.home, color: AppTheme.violet),
            label: 'خانه',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            selectedIcon: const Icon(Icons.auto_awesome, color: AppTheme.violet),
            label: 'برج من',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            selectedIcon: const Icon(Icons.favorite, color: AppTheme.rose),
            label: 'عشق',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            selectedIcon: const Icon(Icons.person, color: AppTheme.violet),
            label: 'پروفایل',
          ),
        ],
      ),
    );
  }
}
