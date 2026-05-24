import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../views/screens/splash_screen.dart';
import '../views/screens/login_screen.dart';
import '../views/screens/register_screen.dart';
import '../views/screens/consumer/consumer_shell.dart';
import '../views/screens/admin/admin_screen.dart';
import '../views/screens/super_admin/super_admin_screen.dart';

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
    _ref.listen<bool>(demoModeProvider, (_, __) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authProvider);
    final isDemo = _ref.read(demoModeProvider);
    final isLoading = authState.loading;
    final path = state.uri.path;

    // Allow splash to show during initial load
    if (isLoading && path == '/splash') return null;

    final loggedIn = isDemo || authState.user != null;
    final profile = authState.profile;

    if (loggedIn && profile != null) {
      // Already on the right screen — don't redirect
      final correctPath = switch (profile.role) {
        UserRole.superAdmin => '/super_admin',
        UserRole.admin => '/admin',
        UserRole.consumer => '/consumer',
      };

      if (path == '/login' ||
          path == '/register' ||
          path == '/splash') {
        return correctPath;
      }

      // Prevent super admin from accessing consumer/admin screens and vice-versa
      if (profile.role == UserRole.superAdmin && path != '/super_admin') {
        return '/super_admin';
      }
      if (profile.role == UserRole.admin && path == '/consumer') {
        return '/admin';
      }
      if (profile.role == UserRole.consumer && path == '/admin') {
        return '/consumer';
      }
    } else if (!isLoading) {
      // Not logged in
      if (path != '/login' &&
          path != '/register' &&
          path != '/splash') {
        return '/login';
      }
    }

    return null;
  }
}

final _routerNotifierProvider = Provider<_RouterNotifier>((ref) {
  return _RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: '/super_admin',
          builder: (_, __) => const SuperAdminScreen()),
      GoRoute(path: '/consumer', builder: (_, __) => const ConsumerShell()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
    ],
  );
});
