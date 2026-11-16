import 'dart:async';
import '../services/credential_service.dart';
import '../views/screens/credential_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'auth_redirect.dart';
import '../views/screens/auth_loading_screen.dart';
import '../views/screens/login_screen.dart';
import '../views/screens/phone_enrollment_screen.dart';
import '../views/screens/generator_requests_screen.dart';
import '../views/screens/account_status_screen.dart';
import '../providers/tenant_provider.dart';
import '../views/screens/consumer/consumer_shell.dart';
import '../views/screens/admin/admin_screen.dart';
import '../views/screens/super_admin/super_admin_screen.dart';

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  Timer? _loginGrace;
  bool _graceExpired = false;
  bool _inLoginResolution = false;

  void _refresh() {
    final auth = _ref.read(authProvider);
    final tenant = _ref.read(tenantAccessProvider);
    final resolving = !auth.startupResolved ||
        (auth.user != null && auth.profile == null && auth.loading) ||
        (auth.profile != null && (tenant?.isLoading ?? false));
    if (!resolving || auth.user == null) {
      _loginGrace?.cancel();
      _inLoginResolution = false;
      _graceExpired = false;
    } else if (!_inLoginResolution) {
      _inLoginResolution = true;
      _loginGrace = Timer(const Duration(milliseconds: 800), () {
        _graceExpired = true;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _loginGrace?.cancel();
    super.dispose();
  }

  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => _refresh());
    _ref.listen<bool>(demoModeProvider, (_, __) => _refresh());
    _ref.listen(tenantAccessProvider, (_, __) => _refresh());
    _ref.listen(credentialFlowProvider, (_, __) => _refresh());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authProvider);
    final isDemo = _ref.read(demoModeProvider);
    final tenant = _ref.read(tenantAccessProvider);
    final path = state.uri.path;
    if (path == '/forgot-password' || path == '/id-register') {
      if (authState.user == null || _ref.read(credentialFlowProvider)) {
        return null;
      }
    }
    if (_ref.read(credentialFlowProvider) &&
        {'/credentials', '/account-security', '/onboarding'}.contains(path)) {
      return null;
    }
    // Resume an interrupted ID-first registration without creating another UID.
    if (authState.startupResolved &&
        authState.needsRegistration &&
        authState.user != null &&
        authState.user!.phoneNumber == null) {
      return path == '/credentials' ? null : '/credentials';
    }
    if (authState.startupResolved &&
        authState.profile != null &&
        !authState.isDemo &&
        authState.needsCredentialCompletion &&
        path != '/forgot-password') {
      return path == '/credentials' ? null : '/credentials';
    }
    if (path == '/account-security' &&
        authState.profile != null &&
        authState.startupResolved) {
      return null;
    }

    final resolving = !authState.startupResolved ||
        (authState.user != null &&
            authState.profile == null &&
            authState.loading) ||
        (authState.profile != null && (tenant?.isLoading ?? false));
    // Keep the existing form for fast sign-in; never route by an unverified role.
    if ({'/login', '/phone', '/register'}.contains(path) &&
        resolving &&
        !_graceExpired) {
      return null;
    }
    return authRedirect(
      path: state.uri.path,
      startupResolved: authState.startupResolved,
      loading: authState.loading,
      loggedIn: isDemo || authState.user != null,
      profile: authState.profile,
      needsRegistration: authState.needsRegistration,
      tenantLoading: tenant?.isLoading ?? false,
      tenantAvailable: tenant == null ||
          (!tenant.hasError && (tenant.valueOrNull?.available ?? false)),
      accountError: authState.error != null &&
          authState.user != null &&
          authState.profile == null,
    );
  }
}

final _routerNotifierProvider = Provider<_RouterNotifier>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
          path: '/credentials',
          builder: (_, __) =>
              const CredentialScreen(mode: CredentialMode.complete)),
      GoRoute(
          path: '/forgot-password',
          builder: (_, __) =>
              const CredentialScreen(mode: CredentialMode.recover)),
      GoRoute(
          path: '/id-register',
          builder: (_, __) =>
              const CredentialScreen(mode: CredentialMode.create)),
      GoRoute(
          path: '/account-security',
          builder: (_, __) =>
              const CredentialScreen(mode: CredentialMode.manage)),
      GoRoute(path: '/splash', builder: (_, __) => const AuthLoadingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: '/register', builder: (_, __) => const PhoneEnrollmentScreen()),
      GoRoute(
          path: '/phone', builder: (_, __) => const PhoneEnrollmentScreen()),
      GoRoute(
          path: '/onboarding',
          builder: (_, __) => const EnrollmentFormScreen()),
      GoRoute(
          path: '/account-status',
          builder: (_, __) => const AccountStatusScreen()),
      GoRoute(
          path: '/generator-requests',
          builder: (_, __) => const GeneratorRequestsScreen()),
      GoRoute(
          path: '/super_admin', builder: (_, __) => const SuperAdminScreen()),
      GoRoute(path: '/consumer', builder: (_, __) => const ConsumerShell()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
    ],
  );
});
