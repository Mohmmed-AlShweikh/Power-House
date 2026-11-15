import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/generator_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../theme/portal_tokens.dart';
import '../widgets/portal_components.dart';

class AccountStatusScreen extends ConsumerWidget {
  const AccountStatusScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final profile = auth.profile;
    final tenant = ref.watch(tenantAccessProvider);
    final generator = tenant?.valueOrNull;
    final rejected = profile?.approvalStatus == ApprovalStatus.rejected ||
        generator?.status == GeneratorApproval.rejected;
    final pending = profile?.approvalStatus == ApprovalStatus.pending ||
        generator?.status == GeneratorApproval.pending;
    final reason = profile?.rejectionReason.isNotEmpty == true
        ? profile!.rejectionReason
        : generator?.rejectionReason ?? '';
    return PortalPage(
        title: 'حالة الطلب',
        subtitle: 'بوابة المولدات',
        reserveNavigation: false,
        children: [
          if (tenant?.isLoading ?? false) const PortalLoadingState(),
          if (auth.error != null || (tenant?.hasError ?? false)) ...[
            const PortalErrorState('تعذّر تحميل حالة الحساب'),
            TextButton(
                onPressed: () {
                  ref.invalidate(currentGeneratorAccountProvider);
                  ref.read(authProvider.notifier).reloadProfile();
                },
                child: const Text('إعادة المحاولة')),
          ] else
            PortalPanel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Icon(
                      rejected
                          ? Icons.cancel_outlined
                          : pending
                              ? Icons.hourglass_top
                              : Icons.pause_circle_outline,
                      size: PortalTokens.target),
                  const SizedBox(height: PortalTokens.lg),
                  Text(
                      rejected
                          ? 'لم تتم الموافقة على الطلب'
                          : pending
                              ? (profile?.role == UserRole.admin
                                  ? 'طلب المولد قيد المراجعة من المشرف العام'
                                  : 'بانتظار موافقة صاحب المولد')
                              : 'الحساب أو اشتراك المولد متوقف حالياً',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center),
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: PortalTokens.lg),
                    Text(reason)
                  ],
                ])),
          const SizedBox(height: PortalTokens.xl),
          TextButton(
              onPressed: () => ref.read(authProvider.notifier).signOut(),
              child: const Text('تسجيل الخروج')),
        ]);
  }
}
