import '../models/user_model.dart';

/// Startup is unresolved until Firebase's first event and role lookup complete.
/// Form submission loading alone must not unmount login/registration forms.
String? authRedirect({
  required String path,
  required bool startupResolved,
  required bool loading,
  required bool loggedIn,
  required UserProfile? profile,
}) {
  if (!startupResolved || (loggedIn && profile == null && loading)) {
    return path == '/splash' ? null : '/splash';
  }
  if (loggedIn && profile != null) {
    final correctPath = switch (profile.role) {
      UserRole.superAdmin => '/super_admin',
      UserRole.admin => '/admin',
      UserRole.consumer => '/consumer',
    };
    if (path == '/splash' || path == '/login' || path == '/register') {
      return correctPath;
    }
    if (profile.role == UserRole.superAdmin && path != '/super_admin') {
      return '/super_admin';
    }
    if (profile.role == UserRole.admin && path == '/consumer') {
      return '/admin';
    }
    if (profile.role == UserRole.consumer && path == '/admin') {
      return '/consumer';
    }
  } else if (!loading && path != '/login' && path != '/register') {
    return '/login';
  }
  return null;
}
