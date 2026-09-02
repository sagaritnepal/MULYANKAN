import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';
import 'features/auth/email_auth_screen.dart';
import 'features/auth/showroom_setup_screen.dart';
import 'features/home/home_shell.dart';
import 'state/auth_provider.dart';

class MulyankanApp extends ConsumerWidget {
  const MulyankanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Mulyankan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const _AuthGate(),
    );
  }
}

/// Routes between login, one-time showroom setup, and the main app based
/// on auth state alone — no named routes needed at this scale.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!auth.isLoggedIn) {
      return const EmailAuthScreen();
    }
    if (!auth.user!.hasShowroom && auth.showroom == null) {
      return const ShowroomSetupScreen();
    }
    return const HomeShell();
  }
}
