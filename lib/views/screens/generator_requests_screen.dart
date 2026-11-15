import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/generator_model.dart';
import '../../providers/tenant_provider.dart';
import '../../theme/portal_tokens.dart';
import '../widgets/portal_components.dart';
import '../widgets/portal_reason_dialog.dart';

class GeneratorRequestsScreen extends ConsumerWidget {
  const GeneratorRequestsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PortalPage(
      title: 'طلبات المولدات',
      subtitle: 'المراجعة وإدارة الاشتراكات',
      reserveNavigation: false,
      actions: [
        IconButton(
            tooltip: 'رجوع',
            onPressed: () => context.go('/super_admin'),
            icon: const Icon(Icons.arrow_back))
      ],
      children: ref.watch(generatorRequestsProvider).when(
            loading: () => [const PortalLoadingState()],
            error: (_, __) => [
              const PortalErrorState('تعذّر تحميل طلبات المولدات'),
              TextButton(
                  onPressed: () => ref.invalidate(generatorRequestsProvider),
                  child: const Text('إعادة المحاولة'))
            ],
            data: (items) => items.isEmpty
                ? [const PortalEmptyState('لا توجد طلبات مولدات')]
                : items
                    .map((g) => Padding(
                        padding: const EdgeInsets.only(bottom: PortalTokens.lg),
                        child: _GeneratorRequestCard(
                            key: ValueKey(g.id), generator: g)))
                    .toList(),
          ));
}

class _GeneratorRequestCard extends ConsumerStatefulWidget {
  final GeneratorAccount generator;
  const _GeneratorRequestCard({super.key, required this.generator});
  @override
  ConsumerState<_GeneratorRequestCard> createState() =>
      _GeneratorRequestCardState();
}

class _GeneratorRequestCardState extends ConsumerState<_GeneratorRequestCard> {
  bool busy = false;
  String? error;
  Future<void> act(GeneratorApproval status,
      {String reason = '', String? subscription}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(tenantStoreProvider).reviewGenerator(
          widget.generator.id, status,
          reason: reason, subscriptionStatus: subscription);
    } catch (_) {
      if (mounted) setState(() => error = 'تعذّر حفظ التغيير. حاول مجدداً.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> reject() async {
    final reason = await requestRejectionReason(context);
    if (reason != null && mounted) {
      await act(GeneratorApproval.rejected, reason: reason);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.generator;
    final label = switch (g.status) {
      GeneratorApproval.pending => 'قيد المراجعة',
      GeneratorApproval.approved => 'مقبول',
      GeneratorApproval.rejected => 'مرفوض',
      GeneratorApproval.suspended => 'موقوف'
    };
    return PortalPanel(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PortalRecordRow(
          title: g.name,
          subtitle: g.sector,
          icon: Icons.electric_bolt_outlined,
          statusLabel: label,
          statusTone: g.status == GeneratorApproval.approved
              ? PortalTone.success
              : PortalTone.warning),
      if (g.rejectionReason.isNotEmpty) Text(g.rejectionReason),
      SwitchListTile(
          title: const Text('اشتراك المولد نشط'),
          value: g.subscriptionStatus == 'active',
          onChanged: busy
              ? null
              : (value) => act(g.status,
                  reason: g.rejectionReason,
                  subscription: value ? 'active' : 'inactive')),
      if (busy)
        const PortalLoadingState()
      else
        Wrap(spacing: PortalTokens.sm, runSpacing: PortalTokens.sm, children: [
          if (g.status != GeneratorApproval.approved)
            ElevatedButton.icon(
                onPressed: () => act(GeneratorApproval.approved),
                icon: const Icon(Icons.check),
                label: Text(g.status == GeneratorApproval.suspended
                    ? 'إعادة التفعيل'
                    : 'موافقة')),
          if (g.status == GeneratorApproval.pending)
            OutlinedButton.icon(
                onPressed: reject,
                icon: const Icon(Icons.close),
                label: const Text('رفض مع السبب')),
          if (g.status == GeneratorApproval.approved)
            OutlinedButton.icon(
                onPressed: () => act(GeneratorApproval.suspended),
                icon: const Icon(Icons.pause),
                label: const Text('تعليق المولد')),
        ]),
      if (error != null) PortalErrorState(error!),
    ]));
  }
}
