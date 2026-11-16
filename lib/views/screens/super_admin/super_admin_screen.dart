import 'package:flutter/material.dart';
import '../generator_requests_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/portal_tokens.dart';
import '../../widgets/portal_components.dart';
import '../../widgets/portal_reason_dialog.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_provider.dart';
import '../../../services/firebase_service.dart';
import '../../../services/notification_service.dart';

class SuperAdminScreen extends ConsumerWidget {
  const SuperAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).profile;
    final pendingAsync = ref.watch(pendingGeneratorOwnersProvider);
    final theme = Theme.of(context);

    final pendingCount = pendingAsync.when(
      data: (list) => list.length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    return Scaffold(
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const PortalBrandMark(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('أصحاب المولدات',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                          fontWeight: FontWeight.w800)),
                              Text(
                                  profile?.name.isNotEmpty == true
                                      ? profile!.name
                                      : 'المشرف العام',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.bug_report,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          tooltip: 'استكشاف الطلبات',
                          onPressed: () async {
                            final db = FirebaseFirestore.instance;
                            try {
                              final snap = await db.collection('users').get();
                              final all = snap.docs.map((d) {
                                final data = d.data();
                                final role = (data['role'] ?? '').toString();
                                final name = (data['name'] ?? '').toString();
                                final status =
                                    (data['status'] ?? '').toString();
                                final idNumber =
                                    (data['idNumber'] ?? '').toString();
                                return 'ID:${d.id} | role:$role | status:$status | name:$name | idNum:$idNumber';
                              }).join('\n');
                              final owners = snap.docs.where((d) {
                                final r = (d.data()['role'] ?? '').toString();
                                return r == 'generator_owner';
                              }).toList();
                              final pendingOwners = owners.where((d) {
                                final s = (d.data()['status'] ?? '').toString();
                                return s == 'pending';
                              }).toList();
                              final info = 'المجموع: ${snap.size} مستند\n'
                                  'أصحاب المولدات: ${owners.length}\n'
                                  'بانتظار الموافقة: ${pendingOwners.length}\n'
                                  '\n--- جميع المستندين ---\n$all';
                              await showDialog(
                                context: context,
                                builder: (_) => Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: PortalDiagnosticDialog(
                                      title: 'بيانات الفايرستور',
                                      info: info,
                                      onClose: () => Navigator.pop(context)),
                                ),
                              );
                            } catch (e) {
                              await showDialog(
                                context: context,
                                builder: (_) => Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: PortalDiagnosticDialog(
                                      title: 'خطأ بالاستكشاف',
                                      info: e.toString(),
                                      onClose: () => Navigator.pop(context)),
                                ),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.logout,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          tooltip: 'تسجيل الخروج',
                          onPressed: () async {
                            await ref.read(authProvider.notifier).signOut();
                            if (context.mounted) context.go('/login');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Stats row
                    Row(
                      children: [
                        _StatChip(
                          icon: Icons.pending_actions,
                          label: 'بانتظار الموافقة',
                          value: '$pendingCount',
                          color: PortalTone.warning.colors(context).$1,
                        ),
                      ],
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 8),
                      Builder(builder: (ctx) {
                        return pendingAsync.when(
                          data: (list) => Text(
                              'DEBUG: pending owners=${list.length}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                          loading: () => Text(
                              'DEBUG: loading pending owners...',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                          error: (e, s) => Text(
                              'DEBUG: error: ${e?.toString() ?? 'unknown'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.error)),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────────
          Padding(
              padding: const EdgeInsets.all(PortalTokens.lg),
              child: PortalActionButton(
                  label: 'إدارة طلبات المولدات',
                  onPressed: () => context.go('/generator-requests'))),
          Expanded(
            child: !ref.watch(authProvider).isDemo
                ? const GeneratorRequestsScreen(embedded: true)
                : pendingAsync.when(
                    data: (owners) => owners.isEmpty
                        ? _EmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: owners.length,
                            itemBuilder: (context, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _OwnerRequestCard(owner: owners[i]),
                            ),
                          ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => const _SuperAdminErrorState(),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatChip(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(PortalTokens.radius),
            border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w800)),
                  Text(label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      );
}

class _OwnerRequestCard extends ConsumerStatefulWidget {
  final UserProfile owner;
  const _OwnerRequestCard({required this.owner});

  @override
  ConsumerState<_OwnerRequestCard> createState() => _OwnerRequestCardState();
}

class _OwnerRequestCardState extends ConsumerState<_OwnerRequestCard> {
  bool _loading = false;

  Future<void> _act(bool approve) async {
    final reason = approve ? null : await requestRejectionReason(context);
    if (!mounted || (!approve && reason == null)) return;
    setState(() => _loading = true);
    try {
      if (approve) {
        await FirebaseService().approveUser(widget.owner.uid);
        NotificationService().notifyUserApproved(widget.owner.uid);
      } else {
        await FirebaseService().rejectUser(widget.owner.uid, reason: reason!);
        NotificationService().notifyUserRejected(widget.owner.uid);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(approve ? 'تمت الموافقة على الطلب ✓' : 'تم رفض الطلب',
                textAlign: TextAlign.right),
            backgroundColor: approve
                ? PortalTone.success.colors(context).$1
                : PortalTone.danger.colors(context).$1));
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('permission')
            ? 'لا تملك صلاحية تنفيذ هذا الإجراء.'
            : 'حدث خطأ: ${e.toString()}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg, textAlign: TextAlign.right),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.owner;
    return PortalPanel(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PortalRecordRow(
          title: o.name.isNotEmpty ? o.name : 'بدون اسم',
          subtitle: 'بانتظار',
          icon: Icons.person_outline,
          statusLabel: 'بانتظار',
          statusTone: PortalTone.warning),
      PortalLabelValue(
          label: 'رقم الهوية', value: o.idNumber.isNotEmpty ? o.idNumber : '—'),
      if (o.address.isNotEmpty)
        PortalDataRow(
            label: 'العنوان',
            value: o.address,
            icon: Icons.location_on_outlined),
      const SizedBox(height: PortalTokens.lg),
      _loading
          ? const Center(
              child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5)))
          : Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _act(false),
                    icon: const Icon(Icons.close, size: 16),
                    label: Text('رفض',
                        style: Theme.of(context).textTheme.bodySmall),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PortalTone.danger.colors(context).$1,
                      side: BorderSide(
                          color: PortalTone.danger.colors(context).$1),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(PortalTokens.radius)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _act(true),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('موافقة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      minimumSize:
                          const Size(PortalTokens.target, PortalTokens.target),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(PortalTokens.radius)),
                    ),
                  ),
                ),
              ],
            ),
    ]));
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: PortalTone.success.colors(context).$2,
                  shape: BoxShape.circle),
              child: Icon(Icons.check_circle,
                  size: 48, color: PortalTone.success.colors(context).$1),
            ),
            const SizedBox(height: 16),
            Text('لا توجد طلبات معلقة',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('جميع طلبات أصحاب المولدات تمت معالجتها',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
}

class _SuperAdminErrorState extends StatelessWidget {
  const _SuperAdminErrorState();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 52, color: PortalTone.warning.colors(context).$1),
              const SizedBox(height: 16),
              Text(
                'تعذّر تحميل بيانات المشرف العام. سجّل الدخول كمشرف عام حقيقي لعرض الطلبات الفعلية.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
}

class _MockOwnersList extends StatefulWidget {
  @override
  State<_MockOwnersList> createState() => _MockOwnersListState();
}

class _MockOwnersListState extends State<_MockOwnersList> {
  final _items = [
    ('أبو علي المجدلاني', '123456789', 'رام الله، حي المصيون'),
    ('خالد أبو سالم', '987654321', 'البيرة، شارع الإرسال'),
    ('سعيد الحمداني', '456789123', 'بيت لحم، الخضر'),
  ];

  final _rejected = <int>{};
  final _approved = <int>{};

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, i) {
        if (_rejected.contains(i) || _approved.contains(i)) {
          return const SizedBox.shrink();
        }
        final item = _items[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(PortalTokens.radiusPanel),
              border: Border.all(
                  color: PortalTone.warning
                      .colors(context)
                      .$1
                      .withValues(alpha: 0.3),
                  width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: PortalTone.warning.colors(context).$2,
                      child: Text(item.$1[0],
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  color: PortalTone.warning.colors(context).$1,
                                  fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.$1,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text('رقم الهوية: ${item.$2}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: PortalTone.warning.colors(context).$2,
                          borderRadius:
                              BorderRadius.circular(PortalTokens.radiusPanel)),
                      child: Text('بانتظار',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      PortalTone.warning.colors(context).$1)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(item.$3,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _rejected.add(i));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: const Text('تم رفض الطلب',
                                  textAlign: TextAlign.right),
                              backgroundColor:
                                  Theme.of(context).scaffoldBackgroundColor));
                        },
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('رفض'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: PortalTone.danger.colors(context).$1,
                          side: BorderSide(
                              color: PortalTone.danger.colors(context).$1),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(PortalTokens.radius)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _approved.add(i));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: const Text('تمت الموافقة ✓',
                                  textAlign: TextAlign.right),
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary));
                        },
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('موافقة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          minimumSize: const Size(
                              PortalTokens.target, PortalTokens.target),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(PortalTokens.radius)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
