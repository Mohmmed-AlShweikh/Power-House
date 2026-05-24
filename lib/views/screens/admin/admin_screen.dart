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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('لوحة الإدارة',
                                style: theme.textTheme.headlineMedium
                                    ?.copyWith(color: Colors.white)),
                            Text('مولد حي البيرة',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: Colors.white60)),
                          ],
                        ),
                        const Spacer(),
                        Consumer(
                          builder: (_, ref, __) {
                            final isDark = theme.brightness == Brightness.dark;
                            return IconButton(
                              icon: Icon(
                                  isDark ? Icons.light_mode : Icons.dark_mode,
                                  color: Colors.white),
                              onPressed: () =>
                                  ref.read(themeProvider.notifier).toggle(),
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
                    generatorOn: _generatorOn,
                    onToggle: (v) => setState(() => _generatorOn = v)),
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
  final bool generatorOn;
  final ValueChanged<bool> onToggle;
  const _DashboardTab({required this.generatorOn, required this.onToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genAsync = ref.watch(generatorProvider);
    final isOn = genAsync.when(
        data: (g) => g.isOn,
        loading: () => generatorOn,
        error: (_, __) => generatorOn);
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
          _GeneratorToggleCard(isOn: isOn, onToggle: onToggle),
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
          _MonthlyBillStatsCard(
              stats: stats, month: currentMonth),
          const SizedBox(height: 16),
          _RecentActivity(),
        ],
      ),
    );
  }
}

class _GeneratorToggleCard extends StatelessWidget {
  final bool isOn;
  final ValueChanged<bool> onToggle;
  const _GeneratorToggleCard({required this.isOn, required this.onToggle});

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
                Text(isOn ? 'يعمل منذ 3 ساعات' : 'اضغط لتشغيل المولد',
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

class _RecentActivity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      ('محمد أحمد', 'رفع إيصال يوليو', 'منذ ساعة', AppColors.success),
      ('سارة خالد', 'شكوى: انقطاع متكرر', 'منذ 3 ساعات', AppColors.error),
      ('أحمد محمود', 'مشترك جديد', 'أمس', AppColors.primary),
    ];
    return Container(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text('آخر النشاطات',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          ...items.map((i) => ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: i.$4.withOpacity(0.15),
                  child: Text(i.$1[0],
                      style:
                          TextStyle(color: i.$4, fontWeight: FontWeight.w700)),
                ),
                title: Text(i.$1,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(i.$2,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.lightMuted)),
                trailing: Text(i.$3,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.lightMuted)),
              )),
        ],
      ),
    ).animate().fadeIn();
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
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _showAddSheet(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('إضافة'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
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
      {required this.sub,
      required this.onToggle,
      required this.onJumpToBill});

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
                    Text(sub.phone,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.lightMuted)),
                    const SizedBox(width: 8),
                    Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                            color: AppColors.lightMuted,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(sub.address,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.lightMuted)),
                  ],
                ),
                const SizedBox(height: 2),
                Text('الأمبير: ${sub.ampereLimit}A',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (isActive ? AppColors.success : AppColors.error)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(isActive ? 'نشط' : 'موقوف',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isActive ? AppColors.success : AppColors.error)),
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
    final billsAsync = ref.watch(allBillsProvider);
    final subsMap = ref.watch(subscribersMapProvider).value ?? {};

    ref.listen<String?>(highlightedBillProvider, (prev, next) {
      if (next != null && next != prev) {
        // Defer setState to avoid "called during build" crash
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _filter = 'all';
            _highlightedBillId = next;
          });
          if (_scrollController.hasClients) {
            _scrollController.animateTo(0,
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOut);
          }
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() => _highlightedBillId = null);
              ref.read(highlightedBillProvider.notifier).state = null;
            }
          });
        });
      }
    });

    return billsAsync.when(
      data: (bills) {
        List<Bill> filtered = _filter == 'all'
            ? List<Bill>.from(bills)
            : bills.where((b) => b.status.name == _filter).toList();

        if (_highlightedBillId != null) {
          final idx = filtered.indexWhere((b) => b.id == _highlightedBillId);
          if (idx > 0) {
            final highlighted = filtered.removeAt(idx);
            filtered = [highlighted, ...filtered];
          }
        }

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
            ...filtered.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AdminBillCard(
                    bill: b,
                    subscriberName: subsMap[b.userId] ?? '',
                    isHighlighted: b.id == _highlightedBillId,
                  ),
                )),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) {
        final filtered = _filter == 'all'
            ? _mockBills
            : _mockBills.where((b) => b.$4 == _filter).toList();
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
            ...filtered.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MockAdminBillCard(
                      name: b.$1, amount: b.$2, month: b.$3, status: b.$4),
                )),
          ],
        );
      },
    );
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
              Text('الفواتير',
                  style: Theme.of(context).textTheme.titleLarge),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
    final canSubmit =
        _idValid && !_submitting && !_checking;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    style: TextStyle(
                        fontSize: 11, color: AppColors.lightMuted)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ID Number field with live validation
          Text('رقم هوية المشترك',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
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
                    hintStyle:
                        const TextStyle(color: AppColors.lightMuted),
                    prefixIcon: const Icon(Icons.badge_outlined,
                        size: 20, color: AppColors.lightMuted),
                    suffixIcon: _checking
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)))
                        : _idChecked
                            ? Icon(
                                _idValid
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: _idValid
                                    ? AppColors.success
                                    : AppColors.error,
                                size: 22)
                            : null,
                    filled: true,
                    fillColor:
                        Theme.of(context).scaffoldBackgroundColor,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.lightBorder)),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('تحقق',
                      style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),

          // ID validation result message
          if (_idChecked) ...[
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (_idValid ? AppColors.success : AppColors.error)
                    .withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                      _idValid
                          ? Icons.person_pin
                          : Icons.person_off_outlined,
                      size: 16,
                      color: _idValid
                          ? AppColors.success
                          : AppColors.error),
                  const SizedBox(width: 8),
                  Text(
                    _idValid
                        ? 'تم التحقق: $_resolvedName'
                        : 'رقم الهوية غير موجود في النظام',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _idValid
                            ? AppColors.success
                            : AppColors.error),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Amount field
          Text('قيمة الفاتورة (₪)',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          _SheetField(
              controller: _amountCtrl,
              hint: 'مثال: 280',
              icon: Icons.payments_outlined,
              keyboardType: TextInputType.number),

          const SizedBox(height: 14),

          // kWh field
          Text('الاستهلاك الشهري (كيلوواط/ساعة)',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
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
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: Text(
                      _displayName.isNotEmpty ? _displayName[0] : '?',
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
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('${bill.month} ${bill.year} • ₪${bill.amount}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.lightMuted)),
                    ],
                  ),
                ),
                if (isHighlighted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
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
                      label:
                          const Text('قبول', style: TextStyle(fontSize: 13)),
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
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('${widget.month} • ${widget.amount}',
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
                    onPressed: () =>
                        setState(() => _localStatus = 'rejected'),
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
                    onPressed: () =>
                        setState(() => _localStatus = 'paid'),
                    icon: const Icon(Icons.check, size: 16),
                    label:
                        const Text('قبول', style: TextStyle(fontSize: 13)),
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
      data: (complaints) => ListView(
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
    return Container(
      padding: const EdgeInsets.all(16),
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
              style: const TextStyle(
                  fontSize: 13, color: AppColors.lightText, height: 1.4)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time,
                  size: 13, color: AppColors.lightMuted),
              const SizedBox(width: 4),
              Text(_timeAgo(item.createdAt),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.lightMuted)),
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
    return 'آمس';
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
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
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
                if (ctrl.text.trim().isEmpty) return;
                await FirebaseService().resolveComplaint(complaintId);
                await NotificationService().addAlert(
                  userId: item.userId,
                  title: 'تم الرد على شكواك',
                  body: ctrl.text.trim(),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8)),
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
    return Container(
      padding: const EdgeInsets.all(16),
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
              style: const TextStyle(
                  fontSize: 13, color: AppColors.lightText, height: 1.4)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time,
                  size: 13, color: AppColors.lightMuted),
              const SizedBox(width: 4),
              Text(time,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.lightMuted)),
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
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
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
                    content: Text('تم إرسال الرد ✓',
                        textAlign: TextAlign.right)));
              },
              style: ElevatedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8)),
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

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [AppColors.primaryDark, AppColors.primary],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.5), width: 2),
                ),
                child: Center(
                  child: Text(
                    (profile?.name.isNotEmpty == true)
                        ? profile!.name[0].toUpperCase()
                        : '؟',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                profile?.name.isNotEmpty == true ? profile!.name : 'صاحب المولد',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('صاحب مولد',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
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
                    _PRow(Icons.phone, 'رقم الهاتف', profile?.phone ?? '—'),
                    const Divider(height: 20, color: AppColors.lightBorder),
                    _PRow(
                        Icons.location_on_outlined,
                        'العنوان',
                        profile?.address?.isNotEmpty == true
                            ? profile!.address
                            : '—'),
                    const Divider(height: 20, color: AppColors.lightBorder),
                    _PRow(
                        Icons.calendar_today,
                        'تاريخ الانضمام',
                        profile != null
                            ? '${profile.createdAt.day}/${profile.createdAt.month}/${profile.createdAt.year}'
                            : '—'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.only(bottom: 8, right: 4),
                child: Text('الإعدادات',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lightMuted)),
              ),
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
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit_outlined,
                            size: 18, color: AppColors.warning),
                      ),
                      title: const Text('تعديل البيانات',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      trailing: const Icon(Icons.chevron_left,
                          color: AppColors.lightMuted, size: 18),
                      onTap: () => _showEditSheet(context, ref),
                    ),
                    const Divider(
                        height: 1, indent: 56, color: AppColors.lightBorder),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.logout,
                            size: 18, color: AppColors.error),
                      ),
                      title: const Text('تسجيل الخروج',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      trailing: const Icon(Icons.chevron_left,
                          color: AppColors.lightMuted, size: 18),
                      onTap: () async {
                        await ref.read(authProvider.notifier).signOut();
                        if (context.mounted) context.go('/login');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text('بوابة المولدات v1.0.0',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.lightMuted.withOpacity(0.6))),
              ),
              const SizedBox(height: 20),
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
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('جميع الطلبات تمت معالجتها',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.lightMuted)),
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
      error: (_, __) => const _MockPendingUsers(),
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('حدث خطأ. حاول مجدداً.', textAlign: TextAlign.right)));
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
                        label: const Text('رفض',
                            style: TextStyle(fontSize: 13)),
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
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                      backgroundColor:
                          AppColors.warning.withOpacity(0.15),
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
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          Text('رقم الهوية: ${item.$2}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.lightMuted)),
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
                            fontSize: 12,
                            color: AppColors.lightMuted)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _done.add(i));
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
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
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
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
