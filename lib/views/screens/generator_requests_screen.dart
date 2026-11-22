import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/generator_model.dart';
import '../../providers/tenant_provider.dart';
import '../../theme/portal_tokens.dart';
import '../widgets/portal_components.dart';
import '../widgets/portal_reason_dialog.dart';

class GeneratorRequestsScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<GeneratorRequestsScreen> createState() =>
      _GeneratorRequestsScreenState();
  final bool embedded;
  const GeneratorRequestsScreen({super.key, this.embedded = false});
}

class _GeneratorRequestsScreenState
    extends ConsumerState<GeneratorRequestsScreen> {
  String search = '';
  GeneratorApproval? filter;
  @override
  Widget build(BuildContext context) {
    final children = [
      TextField(
          decoration: const InputDecoration(
              labelText: 'البحث باسم المولد أو القطاع',
              prefixIcon: Icon(Icons.search)),
          onChanged: (value) => setState(() => search = value.trim())),
      const SizedBox(height: PortalTokens.md),
      DropdownButtonFormField<GeneratorApproval?>(
          initialValue: filter,
          decoration: const InputDecoration(labelText: 'الحالة'),
          items: const [
            DropdownMenuItem(value: null, child: Text('جميع الحالات')),
            DropdownMenuItem(
                value: GeneratorApproval.pending, child: Text('قيد المراجعة')),
            DropdownMenuItem(
                value: GeneratorApproval.approved, child: Text('مقبول')),
            DropdownMenuItem(
                value: GeneratorApproval.rejected, child: Text('مرفوض')),
            DropdownMenuItem(
                value: GeneratorApproval.suspended, child: Text('موقوف')),
          ],
          onChanged: (value) => setState(() => filter = value)),
      const SizedBox(height: PortalTokens.lg),
      ...ref.watch(generatorRequestsProvider).when(
            loading: () => [const PortalLoadingState()],
            error: (_, __) => [
              const PortalErrorState('تعذّر تحميل طلبات المولدات'),
              TextButton(
                  onPressed: () => ref.invalidate(generatorRequestsProvider),
                  child: const Text('إعادة المحاولة'))
            ],
            data: (items) {
              final filtered = items
                  .where((g) =>
                      (filter == null || g.status == filter) &&
                      '${g.name} ${g.sector}'
                          .toLowerCase()
                          .contains(search.toLowerCase()))
                  .toList();
              if (filtered.isEmpty) {
                return [
                  PortalEmptyState(items.isEmpty
                      ? 'لا توجد طلبات مولدات'
                      : 'لا توجد نتائج مطابقة')
                ];
              }
              return filtered
                  .map((g) => Padding(
                      padding: const EdgeInsets.only(bottom: PortalTokens.lg),
                      child: _GeneratorRequestCard(
                          key: ValueKey(g.id), generator: g)))
                  .toList();
            },
          )
    ];
    if (widget.embedded) {
      return ListView(
          padding: const EdgeInsets.all(PortalTokens.lg), children: children);
    }
    return PortalPage(
        title: 'أصحاب المولدات',
        subtitle: 'المراجعة وإدارة الاشتراكات',
        reserveNavigation: false,
        actions: [
          IconButton(
              tooltip: 'رجوع',
              onPressed: () => context.go('/super_admin'),
              icon: const Icon(Icons.arrow_back))
        ],
        children: children);
  }
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
      if (g.ownerUid.isNotEmpty)
        ref.watch(ownerNameProvider(g.ownerUid)).when(
            data: (name) => Text('صاحب المولد: $name'),
            loading: () => const Text('جارٍ تحميل اسم المالك'),
            error: (_, __) => const Text('تعذّر تحميل اسم المالك')),
      if (g.rejectionReason.isNotEmpty) Text(g.rejectionReason),
      SwitchListTile(
          title: const Text('اشتراك المولد'),
          subtitle: Text(g.subscriptionStatus == 'active' ? 'نشط' : 'غير نشط'),
          value: g.subscriptionStatus == 'active',
          onChanged: busy
              ? null
              : (value) async {
                  final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                              title: Text(value
                                  ? 'تفعيل اشتراك المولد؟'
                                  : 'إيقاف اشتراك المولد؟'),
                              content: const Text(
                                  'يؤثر هذا التغيير على دخول صاحب المولد وظهور المولد للمشتركين.'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('إلغاء')),
                                FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('تأكيد'))
                              ]));
                  if (confirmed == true && mounted) {
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      await ref
                          .read(tenantStoreProvider)
                          .setGeneratorSubscription(g.id, value);
                    } catch (_) {
                      if (mounted) {
                        setState(
                            () => error = 'تعذّر حفظ التغيير. حاول مجدداً.');
                      }
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  }
                }),
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
                onPressed: () async {
                  final reason = await requestRejectionReason(context,
                      title: 'سبب إيقاف المولد', actionLabel: 'تأكيد الإيقاف');
                  if (reason != null && mounted) {
                    await act(GeneratorApproval.suspended, reason: reason);
                  }
                },
                icon: const Icon(Icons.pause),
                label: const Text('تعليق المولد')),
        ]),
      if (error != null) PortalErrorState(error!),
    ]));
  }
}
