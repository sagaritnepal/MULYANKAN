import 'package:flutter/material.dart';
import '../feed/vehicle_feed_screen.dart';
import '../poster/poster_home_screen.dart';
import '../valuer/inbox_screen.dart';
import '../dashboard/dashboard_screen.dart';

/// A single account can hold both roles and switch between them — this is
/// the switcher. Both tabs are always shown in Phase 1 for simplicity;
/// there is no separate "become a valuer" flow yet.
///
/// The vehicle feed is first and is what a user lands on after logging in:
/// browsing what is on offer is the common case, while posting and the
/// dashboard are things you go looking for.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          VehicleFeedScreen(),
          DashboardScreen(),
          PosterHomeScreen(),
          InboxScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Post'),
          NavigationDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox), label: 'Inbox'),
        ],
      ),
    );
  }
}
