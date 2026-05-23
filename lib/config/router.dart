import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../views/screens/login_screen.dart';
import '../views/screens/otp_screen.dart';
import '../views/screens/setup_screen.dart';
import '../views/screens/consumer/consumer_shell.dart';
import '../views/screens/admin/admin_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final isDemo = ref.watch(demoModeProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final loggedIn = isDemo || authState.user != null;
      final path = state.uri.path;

      if (loggedIn) {
        if (path == '/login' || path == '/otp') {
          final role = authState.profile?.role ?? 'consumer';
          return role == 'admin' ? '/admin' : '/consumer';
        }
      } else {
        if (path != '/login') return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/otp', builder: (_, __) => const OtpScreen()),
      GoRoute(path: '/setup', builder: (_, __) => const SetupScreen()),
      GoRoute(path: '/consumer', builder: (_, __) => const ConsumerShell()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
    ],
  );
});
