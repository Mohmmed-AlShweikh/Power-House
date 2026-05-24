import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/colors.dart';
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
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
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
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.admin_panel_settings,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('لوحة المشرف العام',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                              Text(
                                  profile?.name.isNotEmpty == true
                                      ? profile!.name
                                      : 'المشرف العام',
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 13)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.bug_report,
                              color: Colors.white70),
                          tooltip: 'استكشاف الطلبات',
                          onPressed: () async {
                            final db = FirebaseFirestore.instance;
                            try {
                              final snap = await db.collection('users').get();
                              final all = snap.docs.map((d) {
                                final data = d.data();
                                final role = (data['role'] ?? '').toString();
                                final name = (data['name'] ?? '').toString();
                                final status = (data['status'] ?? '').toString();
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
                              final info =
                                  'المجموع: ${snap.size} مستند\n'
                                  'أصحاب المولدات: ${owners.length}\n'
                                  'بانتظار الموافقة: ${pendingOwners.length}\n'
                                  '\n--- جميع المستندين ---\n$all';
                              await showDialog(
                                context: context,
                                builder: (_) => Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: AlertDialog(
                                    title: const Text('بيانات الفايرستور'),
                                    content: SingleChildScrollView(
                                      child: SelectableText(info),
                                    ),
                                    actions: [
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context),
                                        child: const Text('حسناً'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            } catch (e) {
                              await showDialog(
                                context: context,
                                builder: (_) => Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: AlertDialog(
                                    title: const Text('خطأ بالاستكشاف'),
                                    content: SelectableText(e.toString()),
                                    actions: [
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context),
                                        child: const Text('حسناً'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white70),
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
                          color: AppColors.warning,
                        ),
                      ],
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 8),
                      Builder(builder: (ctx) {
                        return pendingAsync.when(
                          data: (list) => Text(
                              'DEBUG: pending owners=${list.length}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          loading: () => const Text(
                              'DEBUG: loading pending owners...',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          error: (e, s) => Text(
                              'DEBUG: error: ${e?.toString() ?? 'unknown'}',
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 12)),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────────
          Expanded(
            child: pendingAsync.when(
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
              loading: () => const Center(child: CircularProgressIndicator()),
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
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  Text(label,
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 11)),
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
    setState(() => _loading = true);
    try {
      if (approve) {
        await FirebaseService().approveUser(widget.owner.uid);
        NotificationService().notifyUserApproved(widget.owner.uid);
      } else {
        await FirebaseService().rejectUser(widget.owner.uid);
        NotificationService().notifyUserRejected(widget.owner.uid);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(approve ? 'تمت الموافقة على الطلب ✓' : 'تم رفض الطلب',
              textAlign: TextAlign.right),
          backgroundColor: approve ? AppColors.success : AppColors.error,
        ));
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('permission')
            ? 'لا تملك صلاحية تنفيذ هذا الإجراء.'
            : 'حدث خطأ: ${e.toString()}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg, textAlign: TextAlign.right),
            backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.owner;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.warning.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.warning.withOpacity(0.15),
                child: Text(o.name.isNotEmpty ? o.name[0] : '؟',
                    style: const TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.name.isNotEmpty ? o.name : 'بدون اسم',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(
                        'رقم الهوية: ${o.idNumber.isNotEmpty ? o.idNumber : '—'}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.lightMuted)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: const Text('بانتظار',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning)),
              ),
            ],
          ),
          if (o.address.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: AppColors.lightMuted),
                const SizedBox(width: 4),
                Text(o.address,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.lightMuted)),
              ],
            ),
          ],
          const SizedBox(height: 12),
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
                        label:
                            const Text('رفض', style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _act(true),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('موافقة',
                            style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0, duration: 250.ms);
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
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.check_circle,
                  size: 48, color: AppColors.success),
            ),
            const SizedBox(height: 16),
            const Text('لا توجد طلبات معلقة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('جميع طلبات أصحاب المولدات تمت معالجتها',
                style: TextStyle(fontSize: 13, color: AppColors.lightMuted)),
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
            children: const [
              Icon(Icons.error_outline, size: 52, color: AppColors.warning),
              SizedBox(height: 16),
              Text(
                'تعذّر تحميل بيانات المشرف العام. سجّل الدخول كمشرف عام حقيقي لعرض الطلبات الفعلية.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightMuted),
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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.warning.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.warning.withOpacity(0.15),
                      child: Text(item.$1[0],
                          style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.$1,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          Text('رقم الهوية: ${item.$2}',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.lightMuted)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text('بانتظار',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.warning)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.lightMuted),
                    const SizedBox(width: 4),
                    Text(item.$3,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.lightMuted)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _rejected.add(i));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('تم رفض الطلب',
                                      textAlign: TextAlign.right),
                                  backgroundColor: AppColors.error));
                        },
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('رفض'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _approved.add(i));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('تمت الموافقة ✓',
                                      textAlign: TextAlign.right),
                                  backgroundColor: AppColors.success));
                        },
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('موافقة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
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
