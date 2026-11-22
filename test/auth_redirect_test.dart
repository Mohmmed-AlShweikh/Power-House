import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:generator_portal/config/auth_redirect.dart';
import 'package:generator_portal/models/user_model.dart';
import 'package:generator_portal/providers/auth_provider.dart';
import 'package:generator_portal/views/screens/auth_loading_screen.dart';

UserProfile profile(UserRole role) => UserProfile(
      uid: 'test-user',
      name: 'اختبار',
      role: role,
      createdAt: DateTime(2026),
    );

void main() {
  String? redirect({
    String path = '/splash',
    bool resolved = true,
    bool loading = false,
    bool loggedIn = false,
    UserProfile? userProfile,
  }) =>
      authRedirect(
        path: path,
        startupResolved: resolved,
        loading: loading,
        loggedIn: loggedIn,
        profile: userProfile,
      );

  test('startup resolution survives loading timeout and copyWith', () {
    final state = const AuthState().copyWith(loading: false);
    expect(state.startupResolved, isFalse);
    expect(state.copyWith(startupResolved: true).startupResolved, isTrue);
    expect(redirect(path: '/login', resolved: false), '/splash');
  });

  test('unresolved auth goes to splash without a redirect loop', () {
    expect(redirect(path: '/login', resolved: false, loading: true), '/splash');
    expect(redirect(resolved: false, loading: true), isNull);
    expect(redirect(path: '/admin', resolved: false), '/splash');
  });

  test('signed out goes to login and keeps registration reachable', () {
    expect(redirect(), '/login');
    expect(redirect(path: '/login'), isNull);
    expect(redirect(path: '/register'), isNull);
    expect(redirect(path: '/register', loading: true), isNull);
  });

  test('signed-in Firebase user waits for profile before choosing a role', () {
    expect(redirect(path: '/login', loggedIn: true, loading: true), '/splash');
    expect(redirect(loggedIn: true, loading: true), isNull);
    // A completed failed/missing-profile lookup can return to login.
    expect(redirect(loggedIn: true), '/login');
  });

  for (final role in UserRole.values) {
    final home = switch (role) {
      UserRole.superAdmin => '/super_admin',
      UserRole.admin => '/admin',
      UserRole.consumer => '/consumer',
      UserRole.meterReader => '/reader',
    };
    test('resolved $role goes directly home and stays there', () {
      for (final entry in ['/splash', '/login', '/register']) {
        expect(
            redirect(path: entry, loggedIn: true, userProfile: profile(role)),
            home);
      }
      expect(redirect(path: home, loggedIn: true, userProfile: profile(role)),
          isNull);
    });

    testWidgets('cold start never builds login while restoring $role',
        (tester) async {
      final refresh = ChangeNotifier();
      var resolved = false;
      var loading = true;
      UserProfile? currentProfile;
      var loginBuilds = 0;
      final router = GoRouter(
        initialLocation: '/splash',
        refreshListenable: refresh,
        redirect: (_, state) => authRedirect(
          path: state.uri.path,
          startupResolved: resolved,
          loading: loading,
          loggedIn: true,
          profile: currentProfile,
        ),
        routes: [
          GoRoute(
              path: '/splash', builder: (_, __) => const AuthLoadingScreen()),
          GoRoute(
              path: '/login',
              builder: (_, __) {
                loginBuilds++;
                return const Text('LOGIN');
              }),
          GoRoute(path: home, builder: (_, __) => const Text('HOME')),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(AuthLoadingScreen), findsOneWidget);
      expect(loginBuilds, 0);
      // Simulate the legacy timeout firing before the first Firebase event.
      loading = false;
      refresh.notifyListeners();
      await tester.pump();
      expect(find.byType(AuthLoadingScreen), findsOneWidget);
      currentProfile = profile(role);
      resolved = true;
      refresh.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      expect(loginBuilds, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      refresh.dispose();
    });
  }

  test('existing role restrictions are preserved', () {
    expect(
        redirect(
            path: '/consumer',
            loggedIn: true,
            userProfile: profile(UserRole.admin)),
        '/admin');
    expect(
        redirect(
            path: '/admin',
            loggedIn: true,
            userProfile: profile(UserRole.consumer)),
        '/consumer');
    expect(
        redirect(
            path: '/admin',
            loggedIn: true,
            userProfile: profile(UserRole.superAdmin)),
        '/super_admin');
  });
}
