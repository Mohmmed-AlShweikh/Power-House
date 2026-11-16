import 'package:flutter/material.dart';
import '../generator_requests_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/portal_tokens.dart';
import '../../widgets/portal_components.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_provider.dart';

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
            child: const GeneratorRequestsScreen(embedded: true),
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
