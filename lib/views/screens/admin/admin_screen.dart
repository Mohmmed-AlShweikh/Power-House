import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/user_model.dart';
import '../../../models/bill_model.dart';
import '../../../models/complaint_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/firebase_service.dart';
import '../../../services/local_notification_service.dart';
import '../../../services/notification_service.dart';
import '../../../config/colors.dart';
import '../../widgets/base64_image_viewer.dart';
import 'subscriber_details_screen.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});
  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _generatorOn = true;
  StreamSubscription<QuerySnapshot>? _alertsSub;
  final DateTime _startTime = DateTime.now();
  final Set<String> _seenAlertIds = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startListening());
  }

  void _startListening() {
    final uid = ref.read(authProvider).profile?.uid ?? '';
    if (uid.isEmpty) return;
    _alertsSub = FirebaseFirestore.instance
        .collection('alerts')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final docId = change.doc.id;
        if (_seenAlertIds.contains(docId)) continue;
        _seenAlertIds.add(docId);
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final createdAt = DateTime.fromMillisecondsSinceEpoch(
            (data['createdAt'] as int?) ?? 0);
        if (createdAt.isBefore(_startTime)) continue;
        LocalNotificationService().show(
          (data['title'] as String?) ?? 'تنبيه',
          (data['body'] as String?) ?? '',
        );
      }
    });
  }

  @override
  void dispose() {
    _alertsSub?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  void _jumpToBillsTab(String billId) {
    ref.read(highlightedBillProvider.notifier).state = billId;
    _tabs.animateTo(3);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.settings,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Consumer(
                          builder: (_, ref, __) {
                            final profile = ref.watch(authProvider).profile;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('لوحة الإدارة',
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(color: Colors.white)),
                                Text(
                                    profile != null && profile.name.isNotEmpty
                                        ? profile.name
                                        : 'مولد حي البيرة',
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(color: Colors.white60)),
                              ],
                            );
                          },
                        ),
                        const Spacer(),
                        Consumer(
                          builder: (_, ref, __) {
                            final isDark = theme.brightness == Brightness.dark;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: isDark ? 'وضع النهار' : 'وضع الليل',
                                  icon: Icon(
                                      isDark
                                          ? Icons.light_mode
                                          : Icons.dark_mode,
                                      color: Colors.white),
                                  onPressed: () =>
                                      ref.read(themeProvider.notifier).toggle(),
                                ),
                                IconButton(
                                  tooltip: 'تسجيل الخروج',
                                  icon: const Icon(Icons.logout,
                                      color: Colors.white),
                                  onPressed: () async {
                                    await ref
                                        .read(authProvider.notifier)
                                        .signOut();
                                    if (context.mounted) context.go('/login');
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    indicatorColor: AppColors.success,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: const TextStyle(fontSize: 13),
                    tabs: const [
                      Tab(text: 'نظرة عامة'),
                      Tab(text: 'الطلبات'),
                      Tab(text: 'المشتركون'),
                      Tab(text: 'الفواتير'),
                      Tab(text: 'الشكاوى'),
                      Tab(text: 'ملفي'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _DashboardTab(
                    onToggle: (v) async {
                      await FirebaseService().toggleGenerator(v);
                      await NotificationService().notifyAllUsersGeneratorState(v);
                    }),
                const _PendingUsersTab(),
                _SubscribersTab(onJumpToBill: _jumpToBillsTab),
                const _BillsTab(),
                const _ComplaintsTab(),
                const _AdminProfileTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dashboard Tab ─────────────────────────────────────────────────────────────

class _DashboardTab extends ConsumerWidget {
  final ValueChanged<bool> onToggle;
  const _DashboardTab({required this.onToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genAsync = ref.watch(generatorProvider);
    final isOn = genAsync.when(
        data: (g) => g.isOn,
        loading: () => true,
        error: (_, __) => false);
    final lastChanged = genAsync.when(
        data: (g) => g.lastChanged,
        loading: () => null,
        error: (_, __) => null);
    final stats = ref.watch(monthlyBillStatsProvider);
    final subsAsync = ref.watch(subscribersProvider);
    final complaintsAsync = ref.watch(complaintsProvider);

    final totalSubs = subsAsync.when(
        data: (s) => s.length.toString(),
        loading: () => '…',
        error: (_, __) => '-');
    final activeSubs = subsAsync.when(
        data: (s) => s
            .where((u) => u.subscriptionStatus == SubscriptionStatus.active)
            .length
            .toString(),
        loading: () => '…',
        error: (_, __) => '-');
    final complaintsCount = complaintsAsync.when(
        data: (c) =>
            c.where((x) => x.status == ComplaintStatus.open).length.toString(),
        loading: () => '…',
        error: (_, __) => '-');
    final currentMonth = currentMonthArabic();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _GeneratorToggleCard(isOn: isOn, lastChanged: lastChanged, onToggle: onToggle),
          const SizedBox(height: 16),
          Row(children: [
            _StatBox(
                label: 'المشتركون',
                value: totalSubs,
                icon: Icons.people,
                color: AppColors.primary),
            const SizedBox(width: 12),
            _StatBox(
                label: 'نشطون',
                value: activeSubs,
                icon: Icons.check_circle,
                color: AppColors.success),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _StatBox(
                label: 'شكاوى مفتوحة',
                value: complaintsCount,
                icon: Icons.report,
                color: AppColors.warning),
            const SizedBox(width: 12),
            _StatBox(
                label: 'كWh هذا الشهر',
                value: stats.unpaidCount > 0 || stats.paidCount > 0
                    ? '${(stats.unpaidCount + stats.paidCount)} فاتورة'
                    : '-',
                icon: Icons.bolt,
                color: const Color(0xFF8B5CF6)),
          ]),
          const SizedBox(height: 16),
          _MonthlyBillStatsCard(stats: stats, month: currentMonth),
          const SizedBox(height: 16),
          _RecentActivity(),
        ],
      ),
    );
  }
}

class _GeneratorToggleCard extends StatelessWidget {
  final bool isOn;
  final DateTime? lastChanged;
  final ValueChanged<bool> onToggle;
  const _GeneratorToggleCard(
      {required this.isOn, this.lastChanged, required this.onToggle});

  String _runningFor() {
    if (!isOn) return 'اضغط لتشغيل المولد';
    if (lastChanged == null) return 'يعمل الآن';
    final diff = DateTime.now().difference(lastChanged!);
    if (diff.inDays > 1) return 'يعمل منذ ${diff.inDays} أيام';
    if (diff.inDays == 1) return 'يعمل منذ يوم واحد';
    if (diff.inHours > 1) return 'يعمل منذ ${diff.inHours} ساعات';
    if (diff.inHours == 1) return 'يعمل منذ ساعة واحدة';
    if (diff.inMinutes > 1) return 'يعمل منذ ${diff.inMinutes} دقائق';
    if (diff.inMinutes == 1) return 'يعمل منذ دقيقة';
    return 'يعمل الآن';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOn
              ? [const Color(0xFF16A34A), const Color(0xFF22C55E)]
              : [const Color(0xFF64748B), const Color(0xFF94A3B8)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isOn ? AppColors.success : AppColors.lightMuted)
                .withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25), shape: BoxShape.circle),
            child: Icon(isOn ? Icons.bolt : Icons.power_off,
                color: Colors.white, size: 32),
          ).animate().scaleXY(
              begin: 0.8, end: 1, duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isOn ? 'المولد يعمل' : 'المولد متوقف',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(_runningFor(),
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: isOn,
            onChanged: (v) => _confirmToggle(context, v),
            activeColor: Colors.white,
            activeTrackColor: Colors.white.withOpacity(0.4),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white.withOpacity(0.3),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2, end: 0, duration: 400.ms);
  }

  void _confirmToggle(BuildContext context, bool v) {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(v ? 'تشغيل المولد؟' : 'إيقاف المولد؟'),
          content: Text(v
              ? 'هل تريد تشغيل المولد وإعادة التيار للمشتركين؟'
              : 'هل تريد إيقاف المولد وقطع التيار عن جميع المشتركين؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onToggle(v);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: v ? AppColors.success : AppColors.error,
                minimumSize: Size.zero,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text(v ? 'تشغيل' : 'إيقاف'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatBox(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: color)),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.lightMuted)),
                ],
              ),
            ],
          ),
        ).animate().fadeIn().slideY(begin: 0.2, end: 0, duration: 300.ms),
      );
}

class _RecentActivity extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(recentActivitiesProvider);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Text('آخر النشاطات', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (items.isNotEmpty)
                  Text('${items.length} نشاط',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.lightMuted)),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Row(
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 18,
                      color: theme.brightness == Brightness.dark
                          ? AppColors.darkMuted
                          : AppColors.lightMuted),
                  const SizedBox(width: 8),
                  Text('لا توجد نشاطات حتى الآن',
                      style: TextStyle(
                          fontSize: 13,
                          color: theme.brightness == Brightness.dark
                              ? AppColors.darkMuted
                              : AppColors.lightMuted)),
                ],
              ),
            )
          else
            ...items.map((item) => ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: item.color.withOpacity(0.15),
                    child: Text(
                      item.name.isNotEmpty ? item.name[0] : '؟',
                      style: TextStyle(
                          color: item.color, fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Text(item.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(item.action,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.lightMuted)),
                  trailing: Text(_timeAgo(item.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.lightMuted)),
                )),
          const SizedBox(height: 4),
        ],
      ),
    ).animate().fadeIn();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 1) return 'قبل ${diff.inDays} أيام';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inHours > 1) return 'قبل ${diff.inHours} ساعات';
    if (diff.inHours == 1) return 'قبل ساعة';
    if (diff.inMinutes > 1) return 'قبل ${diff.inMinutes} دقائق';
    if (diff.inMinutes == 1) return 'قبل دقيقة';
    return 'الآن';
  }
}

// ── Monthly Bill Stats Card ───────────────────────────────────────────────────

class _MonthlyBillStatsCard extends StatelessWidget {
  final MonthlyBillStats stats;
  final String month;
  const _MonthlyBillStatsCard({required this.stats, required this.month});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
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
              const Icon(Icons.bar_chart_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('ملخص فواتير $month',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _BillStatItem(
                  label: 'الفواتير المستحقة',
                  count: stats.unpaidCount,
                  amount: stats.unpaidAmount,
                  color: AppColors.error,
                  icon: Icons.pending_actions,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BillStatItem(
                  label: 'الفواتير المدفوعة',
                  count: stats.paidCount,
                  amount: stats.paidAmount,
                  color: AppColors.success,
                  icon: Icons.check_circle_outline,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0, duration: 350.ms);
  }
}

class _BillStatItem extends StatelessWidget {
  final String label;
  final int count;
  final int amount;
  final Color color;
  final IconData icon;
  const _BillStatItem(
      {required this.label,
      required this.count,
      required this.amount,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('$count فاتورة',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text('₪$amount',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.lightMuted)),
        ],
      ),
    );
  }
}

// ── Subscribers Tab ─────────────────────────────────────────────────────────────────

class _SubscribersTab extends ConsumerStatefulWidget {
  final void Function(String billId) onJumpToBill;
  const _SubscribersTab({required this.onJumpToBill});
  @override
  ConsumerState<_SubscribersTab> createState() => _SubscribersTabState();
}

class _SubscribersTabState extends ConsumerState<_SubscribersTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final subsAsync = ref.watch(subscribersProvider);
    final theme = Theme.of(context);

    return subsAsync.when(
      data: (subs) {
        final filtered = _search.isEmpty
            ? subs
            : subs
                .where((s) =>
                    s.name.toLowerCase().contains(_search.toLowerCase()) ||
                    s.phone.replaceAll(' ', '').contains(_search))
                .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.lightBorder),
                      ),
                      child: TextField(
                        onChanged: (v) => setState(() => _search = v.trim()),
                        decoration: InputDecoration(
                          hintText: 'بحث بالاسم أو رقم الجوال...',
                          hintStyle: const TextStyle(
                              color: AppColors.lightMuted, fontSize: 14),
                          prefixIcon: const Icon(Icons.search,
                              color: AppColors.lightMuted, size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 12),
                          prefixIconConstraints:
                              const BoxConstraints(minWidth: 44, minHeight: 44),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SubscriberCard(
                    sub: filtered[i],
                    onJumpToBill: widget.onJumpToBill,
                    onToggle: (v) async {
                      await FirebaseService().updateSubscriber(
                        filtered[i].uid,
                        status: v ? 'active' : 'inactive',
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _MockSubscribers(search: _search),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إضافة مشترك جديد',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 20),
              _SheetField(hint: 'الاسم الكامل', icon: Icons.person_outline),
              const SizedBox(height: 12),
              _SheetField(hint: 'رقم الهاتف (05xxxxxxxx)', icon: Icons.phone),
              const SizedBox(height: 12),
              _SheetField(
                  hint: 'المنطقة / العنوان', icon: Icons.location_on_outlined),
              const SizedBox(height: 12),
              _SheetField(
                  hint: 'الأمبير (الحد الأقصى)', icon: Icons.electric_bolt),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إضافة المشترك'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriberCard extends StatelessWidget {
  final UserProfile sub;
  final ValueChanged<bool> onToggle;
  final void Function(String billId) onJumpToBill;
  const _SubscriberCard(
      {required this.sub, required this.onToggle, required this.onJumpToBill});

  Future<void> _editAmpere(BuildContext context) async {
    final ctrl = TextEditingController(
        text: sub.ampereLimit > 0 ? '${sub.ampereLimit}' : '');
    final result = await showDialog<int>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('حد الأمبير — ${sub.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'أدخل الحد الأقصى للأمبير المسموح به لهذا المشترك',
                style:
                    TextStyle(fontSize: 13, color: AppColors.lightMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'الأمبير',
                  hintText: 'مثال: 10',
                  suffixText: 'A',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  prefixIcon:
                      const Icon(Icons.electric_bolt, size: 20),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                final v = int.tryParse(ctrl.text.trim());
                if (v != null && v > 0) Navigator.pop(context, v);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      await FirebaseService().updateSubscriber(sub.uid, ampereLimit: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = sub.subscriptionStatus == SubscriptionStatus.active;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SubscriberDetailsScreen(
            sub: sub,
            onJumpToBill: onJumpToBill,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: Text(sub.name.isNotEmpty ? sub.name[0] : '?',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sub.name.isNotEmpty ? sub.name : 'بدون اسم',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(sub.phone,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.lightMuted),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                              color: AppColors.lightMuted,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(sub.address,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.lightMuted),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _editAmpere(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.electric_bolt,
                            size: 12,
                            color: sub.ampereLimit > 0
                                ? AppColors.primary
                                : AppColors.warning),
                        const SizedBox(width: 3),
                        Text(
                          sub.ampereLimit > 0
                              ? '${sub.ampereLimit} A'
                              : 'اضغط لتحديد الأمبير',
                          style: TextStyle(
                              fontSize: 11,
                              color: sub.ampereLimit > 0
                                  ? AppColors.primary
                                  : AppColors.warning,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.edit,
                            size: 10,
                            color: sub.ampereLimit > 0
                                ? AppColors.lightMuted
                                : AppColors.warning),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isActive ? AppColors.success : AppColors.error)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(isActive ? 'نشط' : 'موقوف',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color:
                          isActive ? AppColors.success : AppColors.error)),
            ),
            const SizedBox(width: 8),
            Switch(
              value: isActive,
              onChanged: onToggle,
              activeColor: AppColors.success,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ).animate().fadeIn(),
    );
  }
}

class _MockSubscribers extends StatefulWidget {
  final String search;
  const _MockSubscribers({required this.search});

  @override
  State<_MockSubscribers> createState() => _MockSubscribersState();
}

class _MockSubscribersState extends State<_MockSubscribers> {
  String _query = '';
  final _subscribers = [
    UserProfile(
        uid: '1',
        phone: '0591234567',
        name: 'محمد أحمد',
        address: 'رام الله',
        role: UserRole.consumer,
        subscriptionStatus: SubscriptionStatus.active,
        ampereLimit: 10,
        createdAt: DateTime.now()),
    UserProfile(
        uid: '2',
        phone: '0598765432',
        name: 'سارة خالد',
        address: 'البيرة',
        role: UserRole.consumer,
        subscriptionStatus: SubscriptionStatus.active,
        ampereLimit: 15,
        createdAt: DateTime.now()),
    UserProfile(
        uid: '3',
        phone: '0569874521',
        name: 'أحمد محمود',
        address: 'بيت لحم',
        role: UserRole.consumer,
        subscriptionStatus: SubscriptionStatus.inactive,
        ampereLimit: 8,
        createdAt: DateTime.now()),
    UserProfile(
        uid: '4',
        phone: '0554321098',
        name: 'فاطمة علي',
        address: 'الخليل',
        role: UserRole.consumer,
        subscriptionStatus: SubscriptionStatus.active,
        ampereLimit: 12,
        createdAt: DateTime.now()),
    UserProfile(
        uid: '5',
        phone: '0567890123',
        name: 'خالد عمر',
        address: 'نابلس',
        role: UserRole.consumer,
        subscriptionStatus: SubscriptionStatus.active,
        ampereLimit: 20,
        createdAt: DateTime.now()),
    UserProfile(
        uid: '6',
        phone: '0591112233',
        name: 'ليلى حسن',
        address: 'جنين',
        role: UserRole.consumer,
        subscriptionStatus: SubscriptionStatus.inactive,
        ampereLimit: 0,
        createdAt: DateTime.now()),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? _subscribers
        : _subscribers
            .where((s) =>
                s.name.toLowerCase().contains(_query.toLowerCase()) ||
                s.phone.contains(_query))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.lightBorder),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: const InputDecoration(
                      hintText: 'بحث بالاسم أو رقم الجوال...',
                      prefixIcon: Icon(Icons.search,
                          color: AppColors.lightMuted, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtered.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SubscriberCard(
                sub: filtered[i],
                onJumpToBill: (_) {},
                onToggle: (v) => setState(() {
                  final idx = _subscribers.indexOf(filtered[i]);
                  _subscribers[idx] = _subscribers[idx].copyWith(
                    subscriptionStatus: v
                        ? SubscriptionStatus.active
                        : SubscriptionStatus.inactive,
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('إضافة مشترك جديد',
                        style: Theme.of(context).textTheme.headlineMedium),
                  ),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 20),
              _SheetField(
                  controller: nameCtrl,
                  hint: 'الاسم الكامل',
                  icon: Icons.person_outline),
              const SizedBox(height: 12),
              _SheetField(
                  controller: phoneCtrl,
                  hint: 'رقم الهاتف (05xxxxxxxx)',
                  icon: Icons.phone),
              const SizedBox(height: 12),
              _SheetField(
                  controller: addressCtrl,
                  hint: 'المنطقة / العنوان',
                  icon: Icons.location_on_outlined),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  final phone = phoneCtrl.text.trim();
                  if (name.isEmpty || phone.isEmpty) return;
                  setState(() {
                    _subscribers.add(UserProfile(
                      uid: DateTime.now().millisecondsSinceEpoch.toString(),
                      phone: phone,
                      name: name,
                      address: addressCtrl.text.trim(),
                      role: UserRole.consumer,
                      subscriptionStatus: SubscriptionStatus.active,
                      ampereLimit: 10,
                      createdAt: DateTime.now(),
                    ));
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('تم إضافة المشترك ✓',
                            textAlign: TextAlign.right)),
                  );
                },
                child: const Text('إضافة المشترك'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  const _SheetField(
      {required this.hint,
      required this.icon,
      this.controller,
      this.keyboardType});
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.lightMuted),
          prefixIcon: Icon(icon, size: 20, color: AppColors.lightMuted),
          filled: true,
          fillColor: Theme.of(context).scaffoldBackgroundColor,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.lightBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.lightBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      );
}

// ── Bills Tab ─────────────────────────────────────────────────────────────────

class _BillsTab extends ConsumerStatefulWidget {
  const _BillsTab();

  @override
  ConsumerState<_BillsTab> createState() => _BillsTabState();
}

class _BillsTabState extends ConsumerState<_BillsTab> {
  String _filter = 'all';
  String? _highlightedBillId;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  static const _mockBills = [
    ('محمد أحمد', '₪284', 'يوليو 2024', 'pendingReview'),
    ('سارة خالد', '₪310', 'يوليو 2024', 'pendingReview'),
    ('أحمد محمود', '₪254', 'يونيو 2024', 'paid'),
    ('فاطمة علي', '₪296', 'يونيو 2024', 'paid'),
    ('خالد عمر', '₪210', 'مايو 2024', 'paid'),
    ('ليلى حسن', '₪180', 'مايو 2024', 'rejected'),
  ];

  @override
  Widget build(BuildContext context) {
    try {
      final billsAsync = ref.watch(allBillsProvider);
      final subsMap = ref.watch(subscribersMapProvider).value ?? {};

      return billsAsync.when(
        data: (bills) {
          List<Bill> filtered = _filter == 'all'
              ? List<Bill>.from(bills)
              : bills.where((b) => b.status.name == _filter).toList();

          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              _AddBillHeader(onAdd: () => _showAddBillSheet(context)),
              const SizedBox(height: 10),
              _FilterRow(
                  selected: _filter,
                  onSelect: (v) => setState(() => _filter = v)),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('لا توجد فواتير',
                        style: TextStyle(color: AppColors.lightMuted)),
                  ),
                )
              else
                ...filtered.asMap().entries.map((entry) {
                  final b = entry.value;
                  try {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AdminBillCard(
                        bill: b,
                        subscriberName: subsMap[b.userId] ?? '',
                        isHighlighted: false,
                      ),
                    );
                  } catch (e) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.red.withOpacity(0.1),
                      child: Text('Error in bill ${b.id}: $e',
                          style: const TextStyle(color: Colors.red)),
                    );
                  }
                }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) {
          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              _AddBillHeader(onAdd: () => _showAddBillSheet(context)),
              const SizedBox(height: 10),
              _FilterRow(
                  selected: _filter,
                  onSelect: (v) => setState(() => _filter = v)),
              const SizedBox(height: 12),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 40),
                      const SizedBox(height: 12),
                      Text('خطأ في تحميل الفواتير',
                          style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 4),
                      Text(err.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.lightMuted)),
                    ],
                  ),
                ),
              ),
              ..._mockBills
                  .where((b) => _filter == 'all' || b.$4 == _filter)
                  .map((b) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MockAdminBillCard(
                            name: b.$1,
                            amount: b.$2,
                            month: b.$3,
                            status: b.$4),
                      )),
            ],
          );
        },
      );
    } catch (e, st) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text('خطأ: $e',
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.error)),
              const SizedBox(height: 8),
              Text(st.toString(),
                  textAlign: TextAlign.center,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.lightMuted)),
            ],
          ),
        ),
      );
    }
  }

  void _showAddBillSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const Directionality(
        textDirection: TextDirection.rtl,
        child: _AddBillSheet(),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _FilterRow({required this.selected, required this.onSelect});

  static const _filters = [
    ('الكل', 'all'),
    ('غير مدفوعة', 'pending'),
    ('قيد المراجعة', 'pendingReview'),
    ('مقبول', 'paid'),
    ('مرفوض', 'rejected'),
  ];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters
              .map((f) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: GestureDetector(
                      onTap: () => onSelect(f.$2),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected == f.$2
                              ? AppColors.primary
                              : Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: selected == f.$2
                                  ? AppColors.primary
                                  : AppColors.lightBorder),
                        ),
                        child: Text(f.$1,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected == f.$2
                                    ? Colors.white
                                    : AppColors.lightMuted)),
                      ),
                    ),
                  ))
              .toList(),
        ),
      );
}

// ── Add Bill Header ───────────────────────────────────────────────────────────

class _AddBillHeader extends StatelessWidget {
  final VoidCallback onAdd;
  const _AddBillHeader({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final month = currentMonthArabic();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الفواتير', style: Theme.of(context).textTheme.titleLarge),
              Text('شهر $month ${DateTime.now().year}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.lightMuted)),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('إضافة فاتورة'),
          style: ElevatedButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          ),
        ),
      ],
    );
  }
}

// ── Add Bill Sheet ────────────────────────────────────────────────────────────

class _AddBillSheet extends ConsumerStatefulWidget {
  const _AddBillSheet();

  @override
  ConsumerState<_AddBillSheet> createState() => _AddBillSheetState();
}

class _AddBillSheetState extends ConsumerState<_AddBillSheet> {
  final _idCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _kwhCtrl = TextEditingController();

  // Validation state
  bool _checking = false;
  bool _idValid = false;
  bool _idChecked = false;
  String _resolvedName = '';
  String? _resolvedUid;

  bool _submitting = false;

  @override
  void dispose() {
    _idCtrl.dispose();
    _amountCtrl.dispose();
    _kwhCtrl.dispose();
    super.dispose();
  }

  Future<void> _validateId() async {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) return;
    setState(() {
      _checking = true;
      _idChecked = false;
      _idValid = false;
      _resolvedName = '';
      _resolvedUid = null;
    });
    try {
      final uid = await FirebaseService().findUserByIdNumber(id);
      if (!mounted) return;
      if (uid != null) {
        final name = await FirebaseService().getSubscriberName(uid);
        if (!mounted) return;
        setState(() {
          _idValid = true;
          _idChecked = true;
          _resolvedUid = uid;
          _resolvedName = name;
        });
      } else {
        setState(() {
          _idValid = false;
          _idChecked = true;
        });
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _submit() async {
    if (!_idValid || _resolvedUid == null) return;
    final amount = int.tryParse(_amountCtrl.text.trim());
    final kwh = double.tryParse(_kwhCtrl.text.trim());
    if (amount == null || amount <= 0) {
      _showError('أدخل قيمة فاتورة صحيحة');
      return;
    }
    if (kwh == null || kwh <= 0) {
      _showError('أدخل قراءة الاستهلاك صحيحة');
      return;
    }

    setState(() => _submitting = true);
    try {
      final month = currentMonthArabic();
      final year = DateTime.now().year;
      await FirebaseService().createBillWithConsumption(
        userId: _resolvedUid!,
        amount: amount,
        kwh: kwh,
        month: month,
        year: year,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إصدار فاتورة $month لـ $_resolvedName ✓',
            textAlign: TextAlign.right,
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) _showError('فشل إصدار الفاتورة: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg, textAlign: TextAlign.right),
          backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final month = currentMonthArabic();
    final year = DateTime.now().year;
    final canSubmit = _idValid && !_submitting && !_checking;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('إصدار فاتورة جديدة',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text('$month $year — يتم الرصد تلقائياً',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.lightMuted)),
                  ],
                ),
              ),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),

          const SizedBox(height: 20),

          // Auto month badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_month,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('الشهر: $month $year',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
                const SizedBox(width: 6),
                const Text('(تلقائي)',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.lightMuted)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ID Number field with live validation
          Text('رقم هوية المشترك',
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _idCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'أدخل رقم الهوية',
                    hintStyle: const TextStyle(color: AppColors.lightMuted),
                    prefixIcon: const Icon(Icons.badge_outlined,
                        size: 20, color: AppColors.lightMuted),
                    suffixIcon: _checking
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)))
                        : _idChecked
                            ? Icon(_idValid ? Icons.check_circle : Icons.cancel,
                                color: _idValid
                                    ? AppColors.success
                                    : AppColors.error,
                                size: 22)
                            : null,
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.lightBorder)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: _idChecked
                                ? (_idValid
                                    ? AppColors.success
                                    : AppColors.error)
                                : AppColors.lightBorder,
                            width: _idChecked ? 1.5 : 1)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                  onChanged: (_) {
                    if (_idChecked) {
                      setState(() {
                        _idChecked = false;
                        _idValid = false;
                        _resolvedName = '';
                        _resolvedUid = null;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _checking ? null : _validateId,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size.zero,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('تحقق', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),

          // ID validation result message
          if (_idChecked) ...[
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (_idValid ? AppColors.success : AppColors.error)
                    .withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(_idValid ? Icons.person_pin : Icons.person_off_outlined,
                      size: 16,
                      color: _idValid ? AppColors.success : AppColors.error),
                  const SizedBox(width: 8),
                  Text(
                    _idValid
                        ? 'تم التحقق: $_resolvedName'
                        : 'رقم الهوية غير موجود في النظام',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _idValid ? AppColors.success : AppColors.error),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Amount field
          Text('قيمة الفاتورة (₪)',
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          _SheetField(
              controller: _amountCtrl,
              hint: 'مثال: 280',
              icon: Icons.payments_outlined,
              keyboardType: TextInputType.number),

          const SizedBox(height: 14),

          // kWh field
          Text('الاستهلاك الشهري (كيلوواط/ساعة)',
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          _SheetField(
              controller: _kwhCtrl,
              hint: 'مثال: 142.5',
              icon: Icons.bolt_outlined,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true)),

          const SizedBox(height: 22),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : Text(
                      canSubmit
                          ? 'إصدار الفاتورة لـ $_resolvedName'
                          : 'تحقق من رقم الهوية أولاً',
                      style: const TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    ),
  );
  }
}

class _AdminBillCard extends StatelessWidget {
  final Bill bill;
  final String subscriberName;
  final bool isHighlighted;
  const _AdminBillCard(
      {required this.bill,
      this.subscriberName = '',
      this.isHighlighted = false});

  Color get _statusColor => switch (bill.status) {
        BillStatus.pending => AppColors.primary,
        BillStatus.pendingReview => AppColors.warning,
        BillStatus.paid => AppColors.success,
        BillStatus.rejected => AppColors.error,
      };

  String get _statusLabel => switch (bill.status) {
        BillStatus.pending => 'غير مدفوعة',
        BillStatus.pendingReview => 'بانتظار المراجعة',
        BillStatus.paid => 'مقبول',
        BillStatus.rejected => 'مرفوض',
      };

  String get _displayName =>
      subscriberName.isNotEmpty ? subscriberName : bill.userId;

  void _openReviewDialog(BuildContext context) {
    if (bill.status != BillStatus.pendingReview) return;
    showDialog(
      context: context,
      builder: (_) => ReceiptReviewDialog(
        bill: bill,
        subscriberName: _displayName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openReviewDialog(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isHighlighted
              ? AppColors.warning.withOpacity(0.06)
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: isHighlighted
              ? Border.all(color: AppColors.warning, width: 2)
              : Border.all(color: Colors.transparent),
          boxShadow: [
            BoxShadow(
                color: isHighlighted
                    ? AppColors.warning.withOpacity(0.15)
                    : Colors.black.withOpacity(0.04),
                blurRadius: isHighlighted ? 12 : 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: Text(_displayName.isNotEmpty ? _displayName[0] : '?',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('${bill.month} ${bill.year} • ₪${bill.amount}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.lightMuted)),
                    ],
                  ),
                ),
                if (isHighlighted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('جديد',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning)),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_statusLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _statusColor)),
                ),
              ],
            ),
            if (bill.status == BillStatus.pendingReview) ...[
              const SizedBox(height: 12),
              if (bill.receiptBase64 != null)
                GestureDetector(
                  onTap: () => _openReviewDialog(context),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Base64ImageViewer(
                        base64String: bill.receiptBase64!, height: 120),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await FirebaseService()
                            .updateBillStatus(bill.id, BillStatus.rejected);
                        await NotificationService().addAlert(
                          userId: bill.userId,
                          title: 'تم رفض الإيصال',
                          body:
                              'تم رفض إيصال الدفع لفاتورة ${bill.month} ${bill.year}. يرجى التواصل مع المشرف.',
                          type: 'receiptRejected',
                        );
                      },
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('رفض', style: TextStyle(fontSize: 13)),
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
                      onPressed: () async {
                        await FirebaseService()
                            .updateBillStatus(bill.id, BillStatus.paid);
                        await NotificationService().addAlert(
                          userId: bill.userId,
                          title: 'تم قبول الإيصال ✓',
                          body:
                              'تم قبول إيصال الدفع لفاتورة ${bill.month} ${bill.year} بنجاح.',
                          type: 'receiptApproved',
                        );
                      },
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('قبول', style: TextStyle(fontSize: 13)),
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
          ],
        ),
      ),
    ).animate().fadeIn();
  }
}

class _MockAdminBillCard extends StatefulWidget {
  final String name, amount, month, status;
  const _MockAdminBillCard(
      {required this.name,
      required this.amount,
      required this.month,
      required this.status});

  @override
  _MockAdminBillCardState createState() => _MockAdminBillCardState();
}

class _MockAdminBillCardState extends State<_MockAdminBillCard> {
  late String _localStatus;

  @override
  void initState() {
    super.initState();
    _localStatus = widget.status;
  }

  Color get _color => switch (_localStatus) {
        'pendingReview' => AppColors.warning,
        'paid' => AppColors.success,
        _ => AppColors.error,
      };

  String get _label => switch (_localStatus) {
        'pendingReview' => 'بانتظار',
        'paid' => 'مقبول',
        _ => 'مرفوض',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                child: Text(widget.name[0],
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${widget.month} • ${widget.amount}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.lightMuted)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(_label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _color)),
              ),
            ],
          ),
          if (_localStatus == 'pendingReview') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _localStatus = 'rejected'),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('رفض', style: TextStyle(fontSize: 13)),
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
                    onPressed: () => setState(() => _localStatus = 'paid'),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('قبول', style: TextStyle(fontSize: 13)),
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
        ],
      ),
    );
  }
}

// ── Complaints Tab ────────────────────────────────────────────────────────────

class _ComplaintsTab extends ConsumerWidget {
  const _ComplaintsTab();

  static const _items = [
    ('محمد أحمد', 'انقطاع متكرر للتيار خلال ساعات الذروة', 'منذ ساعة', 'open'),
    (
      'سارة خالد',
      'المولد يعطي ضغطاً منخفضاً أضر بالأجهزة',
      'منذ 3 ساعات',
      'inProgress'
    ),
    ('ليلى حسن', 'تأخر في استلام الفاتورة الشهرية', 'أمس', 'open'),
    ('خالد عمر', 'الرسوم الشهرية مرتفعة جداً', 'قبل يومين', 'resolved'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complaintsAsync = ref.watch(complaintsProvider);

    return complaintsAsync.when(
      data: (complaints) => complaints.isEmpty
          ? const _EmptyComplaints()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: complaints
                  .map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ComplaintCard(item: c),
                      ))
                  .toList(),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => ListView(
        padding: const EdgeInsets.all(16),
        children: _items
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MockComplaintCard(
                      name: c.$1, text: c.$2, time: c.$3, status: c.$4),
                ))
            .toList(),
      ),
    );
  }
}

class _EmptyComplaints extends StatelessWidget {
  const _EmptyComplaints();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 56,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '\u0644\u0627 \u062a\u0648\u062c\u062f \u0634\u0643\u0627\u0648\u064a \u0645\u0639\u0644\u0642\u0629',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '\u062c\u0645\u064a\u0639 \u0627\u0644\u0634\u0643\u0627\u0648\u064a \u062a\u0645\u062a \u0627\u0644\u0645\u0639\u0627\u0644\u062c\u0629 \u0628\u0646\u062c\u0627\u062d. \u0627\u0644\u0646\u0638\u0627\u0645 \u064a\u0639\u0645\u0644 \u0628\u0634\u0643\u0644 \u0637\u0628\u064a\u0639\u064a.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.lightMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sentiment_satisfied_alt,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    '\u0627\u0644\u0645\u0634\u062a\u0631\u0643\u0648\n \u0631\u0627\u0636\u064a\u0646 \u0639\u0646 \u0627\u0644\u0645\u0648\u0644\u062f',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  final Complaint item;
  const _ComplaintCard({required this.item});

  Color get _color => switch (item.status) {
        ComplaintStatus.open => AppColors.error,
        ComplaintStatus.inProgress => AppColors.warning,
        _ => AppColors.success,
      };

  String get _label => switch (item.status) {
        ComplaintStatus.open => 'مفتوح',
        ComplaintStatus.inProgress => 'قيد المعالجة',
        _ => 'محلول',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final mutedColor = theme.brightness == Brightness.dark
        ? AppColors.darkMuted
        : AppColors.lightMuted;
    final hasReply = item.reply != null && item.reply!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _color.withOpacity(0.12),
                child: Text(item.userName.isNotEmpty ? item.userName[0] : '?',
                    style:
                        TextStyle(color: _color, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(item.userName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600))),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(_label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _color)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(item.text,
              style: TextStyle(fontSize: 13, color: textColor, height: 1.4)),
          if (hasReply) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.success.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.reply_outlined,
                          size: 14, color: AppColors.success),
                      SizedBox(width: 6),
                      Text('ردك',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(item.reply!,
                      style: TextStyle(fontSize: 13, color: textColor, height: 1.4)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 13, color: mutedColor),
              const SizedBox(width: 4),
              Text(_timeAgo(item.createdAt),
                  style: TextStyle(fontSize: 12, color: mutedColor)),
              const Spacer(),
              if (item.status != ComplaintStatus.resolved)
                TextButton(
                  onPressed: () => _showReplyDialog(context, item.id),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero),
                  child: const Text('الرد على الشكوى',
                      style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return 'قبل ${diff.inDays} يوم';
    if (diff.inHours > 0) return 'قبل ${diff.inHours} ساعة';
    return 'الآن';
  }

  void _showReplyDialog(BuildContext context, String complaintId) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('الرد على الشكوى'),
          content: TextField(
            controller: ctrl,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'اكتب ردك هنا...',
              hintStyle: const TextStyle(color: AppColors.lightMuted),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final replyText = ctrl.text.trim();
                if (replyText.isEmpty) return;
                await FirebaseService()
                    .replyToComplaint(complaintId, replyText);
                await NotificationService().addAlert(
                  userId: item.userId,
                  title: 'تم الرد على شكواك 💬',
                  body: replyText,
                  type: 'complaint',
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('تم إرسال الرد ✓',
                          textAlign: TextAlign.right)));
                }
              },
              style: ElevatedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              child: const Text('إرسال الرد'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MockComplaintCard extends StatelessWidget {
  final String name, text, time, status;
  const _MockComplaintCard(
      {required this.name,
      required this.text,
      required this.time,
      required this.status});

  Color get _color => switch (status) {
        'open' => AppColors.error,
        'inProgress' => AppColors.warning,
        _ => AppColors.success,
      };

  String get _label => switch (status) {
        'open' => 'مفتوح',
        'inProgress' => 'قيد المعالجة',
        _ => 'محلول',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final mutedColor = theme.brightness == Brightness.dark
        ? AppColors.darkMuted
        : AppColors.lightMuted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _color.withOpacity(0.12),
                child: Text(name[0],
                    style:
                        TextStyle(color: _color, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600))),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(_label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _color)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(text,
              style: TextStyle(fontSize: 13, color: textColor, height: 1.4)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 13, color: mutedColor),
              const SizedBox(width: 4),
              Text(time, style: TextStyle(fontSize: 12, color: mutedColor)),
              const Spacer(),
              if (status != 'resolved')
                TextButton(
                  onPressed: () => _showMockReplyDialog(context),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero),
                  child: const Text('الرد على الشكوى',
                      style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  void _showMockReplyDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('الرد على الشكوى'),
          content: TextField(
            controller: ctrl,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'اكتب ردك هنا...',
              hintStyle: const TextStyle(color: AppColors.lightMuted),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (ctrl.text.trim().isEmpty) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content:
                        Text('تم إرسال الرد ✓', textAlign: TextAlign.right)));
              },
              style: ElevatedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              child: const Text('إرسال الرد'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Admin Profile Tab ─────────────────────────────────────────────────────────

class _AdminProfileTab extends ConsumerWidget {
  const _AdminProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).profile;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subsAsync = ref.watch(subscribersProvider);
    final billsStats = ref.watch(monthlyBillStatsProvider);

    final initials = (profile?.name.isNotEmpty == true)
        ? profile!.name[0].toUpperCase()
        : '؟';

    final totalSubs = subsAsync.when(
        data: (s) => s.length, loading: () => 0, error: (_, __) => 0);
    final activeSubs = subsAsync.when(
        data: (s) =>
            s.where((u) => u.subscriptionStatus == SubscriptionStatus.active).length,
        loading: () => 0,
        error: (_, __) => 0);
    final totalBills = billsStats.paidCount + billsStats.unpaidCount;

    final joinDate = profile != null
        ? '${profile.createdAt.day}/${profile.createdAt.month}/${profile.createdAt.year}'
        : '—';

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [AppColors.primaryDark, AppColors.primary],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
          child: Column(
            children: [
              // Avatar with glow ring
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w700)),
                ),
              ).animate().scaleXY(begin: 0.85, end: 1, duration: 400.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 14),
              Text(
                profile?.name.isNotEmpty == true ? profile!.name : 'صاحب المولد',
                style: const TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt, color: Colors.white70, size: 13),
                        const SizedBox(width: 4),
                        const Text('صاحب مولد',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone, color: Colors.white54, size: 12),
                        const SizedBox(width: 4),
                        Text(profile?.phone.isNotEmpty == true ? profile!.phone : '—',
                            style: const TextStyle(color: Colors.white60, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 20),

              // ── Quick Stats ───────────────────────────────────────────────
              Row(
                children: [
                  _ProfileStatChip(
                    label: 'المشتركون',
                    value: '$totalSubs',
                    icon: Icons.people_alt_outlined,
                  ),
                  const SizedBox(width: 10),
                  _ProfileStatChip(
                    label: 'نشطون',
                    value: '$activeSubs',
                    icon: Icons.check_circle_outline,
                  ),
                  const SizedBox(width: 10),
                  _ProfileStatChip(
                    label: 'الفواتير',
                    value: '$totalBills',
                    icon: Icons.receipt_long_outlined,
                  ),
                ],
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0, duration: 350.ms),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),

              // ── البيانات الشخصية ──────────────────────────────────────────
              const _SectionLabel('البيانات الشخصية'),
              Container(
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Column(
                  children: [
                    _InfoTile(
                      icon: Icons.phone_outlined,
                      iconColor: AppColors.primary,
                      label: 'رقم الهاتف',
                      value: profile?.phone.isNotEmpty == true ? profile!.phone : '—',
                    ),
                    _Separator(),
                    _InfoTile(
                      icon: Icons.location_on_outlined,
                      iconColor: AppColors.success,
                      label: 'العنوان',
                      value: profile?.address?.isNotEmpty == true ? profile!.address! : '—',
                    ),
                    _Separator(),
                    _InfoTile(
                      icon: Icons.calendar_today_outlined,
                      iconColor: const Color(0xFF8B5CF6),
                      label: 'تاريخ الانضمام',
                      value: joinDate,
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: 0.15, end: 0, duration: 300.ms),
              const SizedBox(height: 20),

              // ── إعدادات الحساب ────────────────────────────────────────────
              const _SectionLabel('إعدادات الحساب'),
              Container(
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Column(
                  children: [
                    _ActionTile(
                      icon: Icons.edit_outlined,
                      iconColor: AppColors.warning,
                      title: 'تعديل البيانات الشخصية',
                      subtitle: 'تغيير الاسم والعنوان ورقم الهاتف',
                      onTap: () => _showEditSheet(context, ref),
                    ),
                    _Separator(),
                    _ActionTile(
                      icon: isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                      iconColor: AppColors.primary,
                      title: isDark ? 'الوضع الداكن' : 'الوضع الفاتح',
                      subtitle: isDark ? 'اضغط للتبديل للوضع الفاتح' : 'اضغط للتبديل للوضع الداكن',
                      trailing: Switch(
                        value: isDark,
                        onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
                        activeColor: AppColors.primary,
                      ),
                      onTap: () => ref.read(themeProvider.notifier).toggle(),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.15, end: 0, duration: 300.ms),
              const SizedBox(height: 28),

              // ── تسجيل الخروج ─────────────────────────────────────────────
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.error.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      await ref.read(authProvider.notifier).signOut();
                      if (context.mounted) context.go('/login');
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('تسجيل الخروج',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 24),

              Center(
                child: Text('بوابة المولدات v1.0.0',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.lightMuted.withOpacity(0.5))),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    final profile = ref.read(authProvider).profile;
    final nameCtrl = TextEditingController(text: profile?.name ?? '');
    final addressCtrl = TextEditingController(text: profile?.address ?? '');
    final phoneCtrl = TextEditingController(text: profile?.phone ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('تعديل بيانات الحساب',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SheetField(
                  controller: nameCtrl,
                  hint: 'الاسم الكامل',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 12),
                _SheetField(
                  controller: addressCtrl,
                  hint: 'العنوان',
                  icon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 12),
                _SheetField(
                  controller: phoneCtrl,
                  hint: 'رقم الجوال',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),
                StatefulBuilder(builder: (ctx, setS) {
                  bool saving = false;
                  return ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            setS(() => saving = true);
                            await ref
                                .read(authProvider.notifier)
                                .updateProfile(
                                  name: nameCtrl.text.trim(),
                                  address: addressCtrl.text.trim(),
                                  phone: phoneCtrl.text.trim(),
                                );
                            setS(() => saving = false);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('تم حفظ البيانات ✓',
                                        textAlign: TextAlign.right)),
                              );
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : const Text('حفظ التغييرات'),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pending Users Tab ────────────────────────────────────────────────────────

class _PendingUsersTab extends ConsumerWidget {
  const _PendingUsersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingUsersProvider);

    return pendingAsync.when(
      data: (users) => users.isEmpty
          ? Center(
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
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('جميع الطلبات تمت معالجتها',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.lightMuted)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PendingUserCard(user: users[i]),
              ),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.warning),
              const SizedBox(height: 16),
              const Text('تعذّر تحميل الطلبات المعلقة',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(err.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: AppColors.lightMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingUserCard extends ConsumerStatefulWidget {
  final UserProfile user;
  const _PendingUserCard({required this.user});

  @override
  ConsumerState<_PendingUserCard> createState() => _PendingUserCardState();
}

class _PendingUserCardState extends ConsumerState<_PendingUserCard> {
  bool _loading = false;

  Future<void> _act(bool approve) async {
    setState(() => _loading = true);
    try {
      if (approve) {
        await FirebaseService().approveUser(widget.user.uid);
        NotificationService().notifyUserApproved(widget.user.uid);
      } else {
        await FirebaseService().rejectUser(widget.user.uid);
        NotificationService().notifyUserRejected(widget.user.uid);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(approve ? 'تمت الموافقة ✓' : 'تم رفض الطلب',
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
    final u = widget.user;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.warning.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
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
                child: Text(u.name.isNotEmpty ? u.name[0] : '؟',
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
                    Text(u.name.isNotEmpty ? u.name : 'بدون اسم',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(
                        'رقم الهوية: ${u.idNumber.isNotEmpty ? u.idNumber : '—'}',
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
          if (u.address.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: AppColors.lightMuted),
                const SizedBox(width: 4),
                Text(u.address,
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

class _MockPendingUsers extends StatefulWidget {
  const _MockPendingUsers();

  @override
  State<_MockPendingUsers> createState() => _MockPendingUsersState();
}

class _MockPendingUsersState extends State<_MockPendingUsers> {
  final _items = [
    ('خالد محمود', '123456789', 'رام الله، الحي الشمالي'),
    ('سارة عمر', '987654321', 'البيرة، شارع الاستقلال'),
    ('محمد علي', '456789123', 'بيتونيا، المنطقة الغربية'),
  ];
  final _done = <int>{};

  @override
  Widget build(BuildContext context) {
    final visible = List.generate(_items.length, (i) => i)
        .where((i) => !_done.contains(i))
        .toList();

    if (visible.isEmpty) {
      return Center(
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
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: visible.length,
      itemBuilder: (context, idx) {
        final i = visible[idx];
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
                                  fontSize: 14, fontWeight: FontWeight.w700)),
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
                const SizedBox(height: 6),
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
                          setState(() => _done.add(i));
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
                          setState(() => _done.add(i));
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

// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, right: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.lightMuted)),
      );
}

class _PRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _PRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.lightMuted)),
                const SizedBox(height: 1),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      );
}

class _ProfileStatChip extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _ProfileStatChip(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white70, size: 18),
              const SizedBox(height: 5),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 10)),
            ],
          ),
        ),
      );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value;
  const _InfoTile(
      {required this.icon,
      required this.iconColor,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.lightMuted)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  const _ActionTile(
      {required this.icon,
      required this.iconColor,
      required this.title,
      required this.subtitle,
      this.trailing,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.lightMuted)),
                  ],
                ),
              ),
              trailing ??
                  const Icon(Icons.chevron_left,
                      color: AppColors.lightMuted, size: 18),
            ],
          ),
        ),
      );
}

class _Separator extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        indent: 56,
        endIndent: 16,
        color: AppColors.lightBorder,
      );
}
