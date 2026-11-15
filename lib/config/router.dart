import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'auth_redirect.dart';
import '../views/screens/auth_loading_screen.dart';
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
    return authRedirect(
      path: state.uri.path,
      startupResolved: authState.startupResolved,
      loading: authState.loading,
      loggedIn: isDemo || authState.user != null,
      profile: authState.profile,
    );
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
      GoRoute(path: '/splash', builder: (_, __) => const AuthLoadingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: '/super_admin', builder: (_, __) => const SuperAdminScreen()),
      GoRoute(path: '/consumer', builder: (_, __) => const ConsumerShell()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
    ],
  );
});
