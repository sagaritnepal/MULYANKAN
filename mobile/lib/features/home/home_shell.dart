import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/locale_provider.dart';
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
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
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
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: s.navFeed),
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: s.navDashboard),
          NavigationDestination(icon: const Icon(Icons.storefront_outlined), selectedIcon: const Icon(Icons.storefront), label: s.navPost),
          NavigationDestination(icon: const Icon(Icons.inbox_outlined), selectedIcon: const Icon(Icons.inbox), label: s.navInbox),
        ],
      ),
    );
  }
}
