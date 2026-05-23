import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/user_model.dart';
import '../../../models/bill_model.dart';
import '../../../models/complaint_model.dart';
import '../../../providers/data_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/firebase_service.dart';
import '../../../config/colors.dart';
import '../../widgets/base64_image_viewer.dart';

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
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
                      Tab(text: 'المشتركون'),
                      Tab(text: 'الفواتير'),
                      Tab(text: 'الشكاوى'),
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
                const _SubscribersTab(),
                const _BillsTab(),
                const _ComplaintsTab(),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _GeneratorToggleCard(isOn: isOn, onToggle: onToggle),
          const SizedBox(height: 16),
          Row(children: [
            _StatBox(
                label: 'المشتركون',
                value: '24',
                icon: Icons.people,
                color: AppColors.primary),
            const SizedBox(width: 12),
            _StatBox(
                label: 'نشطون',
                value: '21',
                icon: Icons.check_circle,
                color: AppColors.success),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _StatBox(
                label: 'الإيرادات',
                value: '₪6,820',
                icon: Icons.payments,
                color: const Color(0xFF8B5CF6)),
            const SizedBox(width: 12),
            _StatBox(
                label: 'شكاوى',
                value: '3',
                icon: Icons.report,
                color: AppColors.warning),
          ]),
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

// ── Subscribers Tab ─────────────────────────────────────────────────────────────────

class _SubscribersTab extends ConsumerStatefulWidget {
  const _SubscribersTab();
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
  const _SubscriberCard({required this.sub, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isActive = sub.subscriptionStatus == SubscriptionStatus.active;
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
    ).animate().fadeIn();
  }
}

class _MockSubscribers extends StatefulWidget {
  final String search;
  const _MockSubscribers({required this.search});

  @override
  State<_MockSubscribers> createState() => _MockSubscribersState();
}

class _MockSubscribersState extends State<_MockSubscribers> {
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
    final filtered = widget.search.isEmpty
        ? _subscribers
        : _subscribers
            .where((s) =>
                s.name.toLowerCase().contains(widget.search.toLowerCase()) ||
                s.phone.contains(widget.search))
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
                    onChanged: (v) => setState(() {}),
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
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
}

class _SheetField extends StatelessWidget {
  final String hint;
  final IconData icon;
  const _SheetField({required this.hint, required this.icon});
  @override
  Widget build(BuildContext context) => TextField(
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

class _BillsTab extends ConsumerWidget {
  const _BillsTab();

  static const _mockBills = [
    ('محمد أحمد', '₪284', 'يوليو 2024', 'pendingReview'),
    ('سارة خالد', '₪310', 'يوليو 2024', 'pendingReview'),
    ('أحمد محمود', '₪254', 'يونيو 2024', 'paid'),
    ('فاطمة علي', '₪296', 'يونيو 2024', 'paid'),
    ('خالد عمر', '₪210', 'مايو 2024', 'paid'),
    ('ليلى حسن', '₪180', 'مايو 2024', 'rejected'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(allBillsProvider);

    return billsAsync.when(
      data: (bills) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _FilterRow(),
          const SizedBox(height: 12),
          ...bills.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AdminBillCard(bill: b),
              )),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _FilterRow(),
          const SizedBox(height: 12),
          ..._mockBills.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MockAdminBillCard(
                    name: b.$1, amount: b.$2, month: b.$3, status: b.$4),
              )),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow();
  @override
  Widget build(BuildContext context) => Row(
        children: ['الكل', 'بانتظار', 'مقبول', 'مرفوض']
            .asMap()
            .entries
            .map((e) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: e.key == 0
                          ? AppColors.primary
                          : Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: e.key == 0
                              ? AppColors.primary
                              : AppColors.lightBorder),
                    ),
                    child: Text(e.value,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: e.key == 0
                                ? Colors.white
                                : AppColors.lightMuted)),
                  ),
                ))
            .toList(),
      );
}

class _AdminBillCard extends StatelessWidget {
  final Bill bill;
  const _AdminBillCard({required this.bill});

  Color get _statusColor => switch (bill.status) {
        BillStatus.pendingReview => AppColors.warning,
        BillStatus.paid => AppColors.success,
        _ => AppColors.error,
      };

  String get _statusLabel => switch (bill.status) {
        BillStatus.pendingReview => 'بانتظار المراجعة',
        BillStatus.paid => 'مقبول',
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
                child: Text(bill.userId.isNotEmpty ? bill.userId[0] : '?',
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bill.userId,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('${bill.month} ${bill.year} • ₪${bill.amount}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.lightMuted)),
                  ],
                ),
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
              Base64ImageViewer(base64String: bill.receiptBase64!, height: 120),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => FirebaseService()
                        .updateBillStatus(bill.id, BillStatus.rejected),
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
                    onPressed: () => FirebaseService()
                        .updateBillStatus(bill.id, BillStatus.paid),
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
    ).animate().fadeIn();
  }
}

class _MockAdminBillCard extends StatelessWidget {
  final String name, amount, month, status;
  const _MockAdminBillCard(
      {required this.name,
      required this.amount,
      required this.month,
      required this.status});

  Color get _color => switch (status) {
        'pendingReview' => AppColors.warning,
        'paid' => AppColors.success,
        _ => AppColors.error,
      };

  String get _label => switch (status) {
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: Text(name[0],
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                Text('$month • $amount',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.lightMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: _color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Text(_label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: _color)),
          ),
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
                  onPressed: () => FirebaseService().resolveComplaint(item.id),
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
                  onPressed: () {},
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
}
