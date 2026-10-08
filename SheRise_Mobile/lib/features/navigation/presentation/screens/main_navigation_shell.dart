import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme.dart';
import '../../../jobs/presentation/screens/jobs_screen.dart';
import '../../../jobs/presentation/screens/post_job_screen.dart';
import '../../../jobs/presentation/screens/near_me_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../safety/presentation/screens/safety_screen.dart';

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    JobsScreen(),      // Take Work
    PostJobScreen(),   // Give Work
    NearMeScreen(),    // Near Me
    SafetyScreen(),    // Safety SOS
    ProfileScreen(),   // Profile
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppTheme.cardBorder, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: Colors.white,
          elevation: 0,
          indicatorColor: AppTheme.pinkSoft,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.work_outline, color: AppTheme.textMuted),
              selectedIcon: Icon(Icons.work, color: AppTheme.deepRose),
              label: 'Take Work',
            ),
            NavigationDestination(
              icon: Icon(Icons.post_add_outlined, color: AppTheme.textMuted),
              selectedIcon: Icon(Icons.post_add, color: AppTheme.deepRose),
              label: 'Give Work',
            ),
            NavigationDestination(
              icon: Icon(Icons.location_on_outlined, color: AppTheme.textMuted),
              selectedIcon: Icon(Icons.location_on, color: AppTheme.deepRose),
              label: 'Near Me',
            ),
            NavigationDestination(
              icon: Icon(Icons.shield_outlined, color: AppTheme.textMuted),
              selectedIcon: Icon(Icons.shield, color: AppTheme.errorRed),
              label: 'Safety',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: AppTheme.textMuted),
              selectedIcon: Icon(Icons.person, color: AppTheme.deepRose),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
