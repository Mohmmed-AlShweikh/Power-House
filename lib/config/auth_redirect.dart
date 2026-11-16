import '../models/user_model.dart';

/// Startup is unresolved until Firebase's first event and role lookup complete.
/// Form submission loading alone must not unmount login/registration forms.
String? authRedirect({
  required String path,
  required bool startupResolved,
  required bool loading,
  required bool loggedIn,
  required UserProfile? profile,
  bool needsRegistration = false,
  bool tenantLoading = false,
  bool tenantAvailable = true,
  bool accountError = false,
}) {
  if (!startupResolved || (loggedIn && profile == null && loading)) {
    return path == '/splash' ? null : '/splash';
  }
  if (loggedIn && needsRegistration) {
    return path == '/onboarding' ? null : '/onboarding';
  }
  if (loggedIn && accountError) {
    return path == '/account-status' ? null : '/account-status';
  }
  if (loggedIn && profile != null) {
    if (profile.role != UserRole.superAdmin) {
      if (profile.approvalStatus != ApprovalStatus.approved ||
          (profile.role == UserRole.consumer &&
              profile.subscriptionStatus != SubscriptionStatus.active)) {
        return path == '/account-status' ? null : '/account-status';
      }
      if (tenantLoading) return path == '/splash' ? null : '/splash';
      if (!tenantAvailable) {
        return path == '/account-status' ? null : '/account-status';
      }
    }
    final correctPath = switch (profile.role) {
      UserRole.superAdmin => '/super_admin',
      UserRole.admin => '/admin',
      UserRole.consumer => '/consumer',
    };
    final allowed = profile.role == UserRole.superAdmin
        ? <String>{'/super_admin', '/generator-requests'}
        : <String>{correctPath};
    return allowed.contains(path) ? null : correctPath;
  } else if (!loading &&
      path != '/login' &&
      path != '/register' &&
      path != '/forgot-password') {
    return '/login';
  }
  return null;
}
