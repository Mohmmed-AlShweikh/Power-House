import '../../../features/billing_settings/models.dart';
import '../../../features/billing_settings/providers.dart';
import '../../../services/firestore_reads.dart';
import '../../../providers/tenant_provider.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
import '../../../theme/portal_tokens.dart';
import '../../widgets/portal_components.dart';
import '../../widgets/portal_keyboard.dart';
import '../../widgets/portal_reason_dialog.dart';
import '../../widgets/portal_number.dart';
import '../../../theme/portal_theme.dart';
import '../../widgets/portal_navigation.dart';
import 'subscriber_details_screen.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});
  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  int _index = 0;
  final _visited = <int>{0};

  void _selectTab(int index) {
    setState(() {
      _index = index;
      _visited.add(index);
    });
  }

  bool _moreVisible = false;
  StreamSubscription<QuerySnapshot>? _alertsSub;
  final DateTime _startTime = DateTime.now();
  final Set<String> _seenAlertIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startListening());
  }

  void _startListening() {
    unawaited(_alertsSub?.cancel());
    _alertsSub = null;
    final auth = ref.read(authProvider);
    final uid = auth.profile?.uid ?? '';
    if (uid.isEmpty || auth.user == null || !auth.startupResolved) return;
    _alertsSub = retryFirestore(() => ref
        .read(firestoreProvider)
        .collection('alerts')
        .where('userId', isEqualTo: uid)
        .where('generatorId',
            isEqualTo: ref.read(authProvider).profile?.generatorId ?? 'default')
        .snapshots()).listen((snapshot) {
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
    }, onError: (Object error, StackTrace stack) {});
  }

  @override
  void dispose() {
    _alertsSub?.cancel();
    super.dispose();
  }

  void _jumpToBillsTab(String billId) {
    ref.read(highlightedBillProvider.notifier).state = billId;
    _selectTab(3);
  }

  Future<void> _showMore(BuildContext context) async {
    setState(() => _moreVisible = true);
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
            top: false,
            child: SingleChildScrollView(
                child: Padding(
                    key: const ValueKey('admin-more-menu'),
                    padding: PortalTokens.pagePadding,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text('المزيد',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge)),
                            IconButton(
                                tooltip: 'إغلاق',
                                onPressed: () => Navigator.pop(sheetContext),
                                icon: const Icon(Icons.close))
                          ]),
                          ListTile(
                              leading:
                                  const Icon(Icons.pending_actions_outlined),
                              title: const Text('الطلبات'),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                _selectTab(1);
                              }),
                          ListTile(
                              leading: const Icon(Icons.person_outline),
                              title: const Text('ملفي'),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                _selectTab(5);
                              }),
                          ListTile(
                              leading: const Icon(Icons.tune_outlined),
                              title: const Text('السعر وجدول التشغيل'),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                final gen = ref.read(generatorProvider);
                                _DashboardTab._showGeneratorSettingsSheet(
                                    context,
                                    gen.when(
                                        data: (g) => g.pricePerKwh,
                                        loading: () => 2.0,
                                        error: (_, __) => 2.0),
                                    gen.when(
                                        data: (g) => g.scheduledOnAt,
                                        loading: () => null,
                                        error: (_, __) => null),
                                    gen.when(
                                        data: (g) => g.scheduledOffAt,
                                        loading: () => null,
                                        error: (_, __) => null));
                              }),
                          ListTile(leading: const Icon(Icons.calculate_outlined), title: const Text('إعدادات الفوترة'), onTap: () { Navigator.pop(sheetContext); context.push('/billing-settings'); }),
                          ListTile(leading: const Icon(Icons.electric_meter_outlined),title:const Text('جولات القراءة والفوترة'),onTap:(){Navigator.pop(sheetContext);context.push('/rounds');}),
                          ListTile(leading: const Icon(Icons.badge_outlined),title:const Text('عمال قراءة العدادات'),onTap:(){Navigator.pop(sheetContext);context.push('/meter-staff');}),
                          ListTile(
                              leading: const Icon(Icons.brightness_6_outlined),
                              title: const Text('تبديل المظهر'),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                ref.read(themeProvider.notifier).toggle();
                              }),
                          ListTile(
                              leading: const Icon(Icons.logout),
                              title: const Text('تسجيل الخروج'),
                              onTap: () async {
                                Navigator.pop(sheetContext);
                                await ref.read(authProvider.notifier).signOut();
                                if (context.mounted) context.go('/login');
                              }),
                        ])))));
    if (mounted) setState(() => _moreVisible = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (_, __) => _startListening());
    final theme = Theme.of(context);
    return Theme(
        data: buildPortalTheme(theme.brightness),
        child: Builder(builder: (context) {
          final profile = ref.watch(authProvider).profile;
          return Scaffold(
              body: Stack(children: [
            Column(children: [
              PortalIdentityBar(
                  title: [
                    'نظرة عامة',
                    'الطلبات',
                    'المشتركون',
                    'الفواتير',
                    'الشكاوى',
                    'ملفي'
                  ][_index],
                  subtitle: profile != null && profile.name.isNotEmpty
                      ? profile.name
                      : 'مولد حي البيرة'),
              Expanded(
                  child: IndexedStack(
                      key: const ValueKey('admin-pages'),
                      index: _index,
                      children: [
                        _DashboardTab(onToggle: (v) async {
                          await FirebaseService().toggleGenerator(v);
                          await NotificationService()
                              .notifyAllUsersGeneratorState(v);
                        }),
                        _visited.contains(1)
                            ? const _PendingUsersTab()
                            : const SizedBox.shrink(),
                        _visited.contains(2)
                            ? _SubscribersTab(onJumpToBill: _jumpToBillsTab)
                            : const SizedBox.shrink(),
                        _visited.contains(3)
                            ? const _BillsTab()
                            : const SizedBox.shrink(),
                        _visited.contains(4)
                            ? const _ComplaintsTab()
                            : const SizedBox.shrink(),
                        _visited.contains(5)
                            ? const _AdminProfileTab()
                            : const SizedBox.shrink(),
                      ]
                          .asMap()
                          .entries
                          .map((entry) => TickerMode(
                                enabled: entry.key == _index,
                                child: entry.value,
                              ))
                          .toList())),
            ]),
            PositionedDirectional(
                start: 0,
                end: 0,
                bottom: MediaQuery.paddingOf(context).bottom,
                child: PortalFloatingNavigation(
                    items: adminNavItems,
                    selected: _moreVisible
                        ? 4
                        : switch (_index) {
                            0 => 0,
                            2 => 1,
                            3 => 2,
                            4 => 3,
                            _ => 4,
                          },
                    onSelected: (i) {
                      if (i == 4) {
                        _showMore(context);
                      } else {
                        _selectTab([0, 2, 3, 4][i]);
                      }
                    })),
          ]));
        }));
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
        data: (g) => g.isOn, loading: () => true, error: (_, __) => false);
    final lastChanged = genAsync.when(
        data: (g) => g.lastChanged,
        loading: () => null,
        error: (_, __) => null);
    final currentPrice = genAsync.when(
        data: (g) => g.pricePerKwh, loading: () => 2.0, error: (_, __) => 2.0);
    final scheduledOnAt = genAsync.when(
        data: (g) => g.scheduledOnAt,
        loading: () => null,
        error: (_, __) => null);
    final scheduledOffAt = genAsync.when(
        data: (g) => g.scheduledOffAt,
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
      padding: EdgeInsets.fromLTRB(
          PortalTokens.gutter,
          PortalTokens.sm,
          PortalTokens.gutter,
          PortalTokens.navClearance + MediaQuery.paddingOf(context).bottom),
      child: Column(children: [
        _GeneratorToggleCard(
            isOn: isOn,
            lastChanged: lastChanged,
            pricePerKwh: currentPrice,
            scheduledOnAt: scheduledOnAt,
            scheduledOffAt: scheduledOffAt,
            onToggle: onToggle),
        PortalSection('ملخص فواتير $currentMonth'),
        PortalMetricPair(
            first: PortalMetric(
                label: 'الفواتير المستحقة',
                value: '₪${stats.unpaidAmount}',
                footnote: '${stats.unpaidCount} فاتورة',
                icon: Icons.pending_actions_outlined),
            second: PortalMetric(
                label: 'الفواتير المدفوعة',
                value: '₪${stats.paidAmount}',
                footnote: '${stats.paidCount} فاتورة',
                icon: Icons.check_circle_outline)),
        const PortalSection('المشتركون والتشغيل'),
        PortalPanel(
            child: Column(children: [
          PortalDataRow(
              label: 'المشتركون', value: totalSubs, icon: Icons.people_outline),
          const Divider(height: PortalTokens.line),
          PortalDataRow(
              label: 'نشطون',
              value: activeSubs,
              icon: Icons.check_circle_outline),
          const Divider(height: PortalTokens.line),
          PortalDataRow(
              label: 'شكاوى مفتوحة',
              value: complaintsCount,
              icon: Icons.chat_bubble_outline),
          const Divider(height: PortalTokens.line),
          PortalDataRow(
              label: 'عدد الفواتير هذا الشهر',
              value: stats.unpaidCount > 0 || stats.paidCount > 0
                  ? '${stats.unpaidCount + stats.paidCount} فاتورة'
                  : '-',
              icon: Icons.electric_bolt_outlined),
        ])),
        const PortalSection('آخر النشاطات'),
        _RecentActivity(),
      ]),
    );
  }

  static void _showGeneratorSettingsSheet(
    BuildContext context,
    double currentPrice,
    DateTime? scheduledOnAt,
    DateTime? scheduledOffAt,
  ) {
    showPortalFormSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        final priceController =
            TextEditingController(text: currentPrice.toStringAsFixed(2));
        var onTime = scheduledOnAt != null
            ? TimeOfDay.fromDateTime(scheduledOnAt)
            : const TimeOfDay(hour: 8, minute: 0);
        var offTime = scheduledOffAt != null
            ? TimeOfDay.fromDateTime(scheduledOffAt)
            : const TimeOfDay(hour: 20, minute: 0);

        Future<void> pickTime(bool isOnTime) async {
          final result = await showTimePicker(
            context: context,
            initialTime: isOnTime ? onTime : offTime,
          );
          if (result == null) return;
          if (isOnTime) {
            onTime = result;
          } else {
            offTime = result;
          }
        }

        String formatTime(TimeOfDay time) {
          final hour = time.hour.toString().padLeft(2, '0');
          final minute = time.minute.toString().padLeft(2, '0');
          return '$hour:$minute';
        }

        return Padding(
          padding: const EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24,
          ),
          child: StatefulBuilder(builder: (context, setState) {
            return SingleChildScrollView(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('السعر وجدول التشغيل',
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('السعر الحالي للوحدة',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                TextField(
                  controller: priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'مثال: 2.50',
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(PortalTokens.radiusPanel)),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 16),
                Text('توقيت تشغيل المولد',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await pickTime(true);
                          setState(() {});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  PortalTokens.radiusPanel)),
                        ),
                        child: Text('تشغيل ${formatTime(onTime)}'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await pickTime(false);
                          setState(() {});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  PortalTokens.radiusPanel)),
                        ),
                        child: Text('إيقاف ${formatTime(offTime)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final price = double.tryParse(
                          priceController.text.trim().replaceAll(',', '.'));
                      if (price == null || price <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('أدخل سعرًا صالحًا.')),
                        );
                        return;
                      }
                      try {
                        final now = DateTime.now();
                        await FirebaseService().updatePricePerKwh(price);
                        await FirebaseService().updateGeneratorSchedule(
                          scheduledOnMillis: DateTime(now.year, now.month,
                                  now.day, onTime.hour, onTime.minute)
                              .millisecondsSinceEpoch,
                          scheduledOffMillis: DateTime(now.year, now.month,
                                  now.day, offTime.hour, offTime.minute)
                              .millisecondsSinceEpoch,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('تم تحديث السعر والجدول بنجاح.')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('فشل التحديث: ${e.toString()}')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(PortalTokens.radiusPanel)),
                    ),
                    child: const Text('حفظ التعديلات'),
                  ),
                ),
              ],
            ));
          }),
        );
      },
    );
  }
}

class _GeneratorToggleCard extends StatelessWidget {
  final bool isOn;
  final DateTime? lastChanged;
  final double pricePerKwh;
  final DateTime? scheduledOnAt;
  final DateTime? scheduledOffAt;
  final ValueChanged<bool> onToggle;

  const _GeneratorToggleCard({
    required this.isOn,
    this.lastChanged,
    required this.pricePerKwh,
    this.scheduledOnAt,
    this.scheduledOffAt,
    required this.onToggle,
  });

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

  String _formatTime(DateTime? dt) {
    if (dt == null) return 'غير محدد';
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) => PortalGeneratorPanel(
        isOn: isOn,
        detail: _runningFor(),
        tariff: '₪${pricePerKwh.toStringAsFixed(2)}',
        scheduledOnValue: _formatTime(scheduledOnAt),
        scheduledOffValue: _formatTime(scheduledOffAt),
        onToggle: (v) => _confirmToggle(context, v),
      );

  void _confirmToggle(BuildContext context, bool v) {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PortalTokens.radiusPanel)),
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
                backgroundColor: v
                    ? PortalTone.success.colors(context).$1
                    : PortalTone.danger.colors(context).$1,
                minimumSize:
                    const Size(PortalTokens.target, PortalTokens.target),
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

class _RecentActivity extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(recentActivitiesProvider);
    final theme = Theme.of(context);

    return PortalPanel(
        child: items.isEmpty
            ? const PortalEmptyState('لا توجد نشاطات حتى الآن')
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${items.length} نشاط',
                    style: theme.textTheme.labelMedium),
                ...items.map((item) => PortalRecordRow(
                    title: item.name,
                    subtitle: item.action,
                    trailing: _timeAgo(item.createdAt),
                    icon: Icons.history_outlined)),
              ]));
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
                        borderRadius:
                            BorderRadius.circular(PortalTokens.radius),
                        border: Border.all(
                            color:
                                Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: TextField(
                        onChanged: (v) => setState(() => _search = v.trim()),
                        decoration: InputDecoration(
                          hintText: 'بحث بالاسم أو رقم الجوال...',
                          hintStyle: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                          prefixIcon: Icon(Icons.search,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              size: 20),
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
              child: filtered.isEmpty
                  ? PortalEmptyState(
                      _search.isEmpty
                          ? 'لا يوجد مشتركون'
                          : 'لا توجد نتائج للبحث',
                      icon: Icons.people_outline)
                  : ListView.builder(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          PortalTokens.gutter,
                          PortalTokens.lg,
                          PortalTokens.gutter,
                          PortalTokens.navClearance +
                              MediaQuery.paddingOf(context).bottom),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SubscriberCard(
                          sub: filtered[i],
                          onJumpToBill: widget.onJumpToBill,
                          onToggle: (v) async {
                            final reason = v
                                ? ''
                                : await requestRejectionReason(context,
                                    title: 'سبب إيقاف المشترك',
                                    actionLabel: 'تأكيد الإيقاف');
                            if (reason == null) return;
                            await FirebaseService().updateSubscriber(
                              filtered[i].uid,
                              status: v ? 'active' : 'inactive',
                              reason: reason,
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
      error: (_, __) => const PortalErrorState('تعذّر تحميل المشتركين'),
    );
  }

  void _showAddSheet(BuildContext context) {
    showPortalFormSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إضافة مشترك جديد',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 20),
              const _SheetField(
                  hint: 'الاسم الكامل', icon: Icons.person_outline),
              const SizedBox(height: 12),
              const _SheetField(
                  hint: 'رقم الهاتف (05xxxxxxxx)', icon: Icons.phone),
              const SizedBox(height: 12),
              const _SheetField(
                  hint: 'المنطقة / العنوان', icon: Icons.location_on_outlined),
              const SizedBox(height: 12),
              const _SheetField(
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
    final result = await showPortalFormDialog<int>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PortalTokens.radiusPanel)),
          title: Text('حد الأمبير — ${sub.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'أدخل الحد الأقصى للأمبير المسموح به لهذا المشترك',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                      borderRadius: BorderRadius.circular(PortalTokens.radius)),
                  prefixIcon: const Icon(Icons.electric_bolt, size: 20),
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
    return InkWell(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => SubscriberDetailsScreen(
                    sub: sub, onJumpToBill: onJumpToBill))),
        child: PortalPanel(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              PortalRecordRow(
                  title: sub.name.isNotEmpty ? sub.name : 'بدون اسم',
                  subtitle: sub.address,
                  icon: Icons.person_outline,
                  statusLabel: isActive ? 'نشط' : 'موقوف',
                  statusTone:
                      isActive ? PortalTone.success : PortalTone.stopped),
              PortalLabelValue(label: 'رقم الهاتف', value: sub.phone),
              const SizedBox(height: PortalTokens.sm),
              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: () => _editAmpere(context),
                        icon: const Icon(Icons.edit_outlined),
                        label: PortalNumber(sub.ampereLimit > 0
                            ? '${sub.ampereLimit} A'
                            : 'اضغط لتحديد الأمبير'))),
                const SizedBox(width: PortalTokens.md),
                Switch(value: isActive, onChanged: onToggle),
              ]),
            ])));
  }
}

class _SheetField extends StatelessWidget {
  final bool readOnly;
  final String hint;
  final IconData icon;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  const _SheetField(
      {required this.hint,
      required this.icon,
      this.controller,
      this.keyboardType,
      this.readOnly = false});
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          prefixIcon: Icon(icon,
              size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          filled: true,
          fillColor: Theme.of(context).scaffoldBackgroundColor,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PortalTokens.radius),
              borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PortalTokens.radius),
              borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PortalTokens.radius),
              borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary, width: 2)),
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
            padding: EdgeInsetsDirectional.fromSTEB(
                PortalTokens.gutter,
                PortalTokens.lg,
                PortalTokens.gutter,
                PortalTokens.navClearance +
                    MediaQuery.paddingOf(context).bottom),
            children: [
              _AddBillHeader(onAdd: () => _showAddBillSheet(context)),
              const SizedBox(height: 10),
              _FilterRow(
                  selected: _filter,
                  onSelect: (v) => setState(() => _filter = v)),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('لا توجد فواتير',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
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
                      color: PortalTone.danger.colors(context).$2,
                      child: Text('Error in bill ${b.id}: $e',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: PortalTone.danger.colors(context).$1)),
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
            padding: EdgeInsetsDirectional.fromSTEB(
                PortalTokens.gutter,
                PortalTokens.lg,
                PortalTokens.gutter,
                PortalTokens.navClearance +
                    MediaQuery.paddingOf(context).bottom),
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
                      Icon(Icons.error_outline,
                          color: PortalTone.danger.colors(context).$1,
                          size: 40),
                      const SizedBox(height: 12),
                      Text('خطأ في تحميل الفواتير',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: PortalTone.danger.colors(context).$1)),
                      const SizedBox(height: 4),
                      Text(err.toString(),
                          textAlign: TextAlign.center,
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
              ),
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
              Icon(Icons.error_outline,
                  color: PortalTone.danger.colors(context).$1, size: 48),
              const SizedBox(height: 16),
              Text('خطأ: $e',
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: PortalTone.danger.colors(context).$1)),
              const SizedBox(height: 8),
              Text(st.toString(),
                  textAlign: TextAlign.center,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }
  }

  void _showAddBillSheet(BuildContext context) {
    showPortalFormSheet(
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
      child: Row(textDirection: TextDirection.rtl, children: [
        for (final f in _filters)
          Padding(
              padding: const EdgeInsetsDirectional.only(end: PortalTokens.sm),
              child: Semantics(
                  selected: selected == f.$2,
                  child: OutlinedButton.icon(
                      onPressed: () => onSelect(f.$2),
                      icon: Icon(
                          selected == f.$2 ? Icons.check : Icons.filter_list,
                          size: PortalTokens.lg),
                      label: Text(f.$1),
                      style: OutlinedButton.styleFrom(
                          backgroundColor: selected == f.$2
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surface,
                          side: BorderSide(
                              width: selected == f.$2
                                  ? PortalTokens.focusLine
                                  : PortalTokens.line,
                              color: Theme.of(context).colorScheme.primary)))))
      ]));
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('إضافة فاتورة'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(PortalTokens.target, PortalTokens.target),
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

  void _calculateAmount() {
    try {
      final settings = ref.read(billingSettingsProvider).valueOrNull;
      if(settings == null) { _amountCtrl.clear(); return; }
      final result = calculateBill(previousMilli: 0, currentMilli: parseFixed(_kwhCtrl.text, 3), settings: settings);
      _amountCtrl.text = (result.amountAgorot ~/ 100).toString();
    } catch (_) { _amountCtrl.clear(); }
    setState(() {});
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
      final now = DateTime.now();
      final weekNumber = ((now.day - 1) ~/ 7) + 1;
      await FirebaseService().createBillWithConsumption(
        userId: _resolvedUid!,
        amount: amount,
        kwh: kwh,
        month: month,
        year: year,
        weekNumber: weekNumber,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
              'تم إصدار فاتورة $month لـ $_resolvedName ✓',
              textAlign: TextAlign.right,
            ),
            backgroundColor: PortalTone.success.colors(context).$1),
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
          backgroundColor: PortalTone.danger.colors(context).$1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final month = currentMonthArabic();
    final year = DateTime.now().year;
    final billing = ref.watch(billingSettingsProvider);
    final canSubmit = _idValid && !_submitting && !_checking && billing.hasValue && !billing.hasError;

    return Padding(
      padding: const EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 28,
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
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),

            const SizedBox(height: 20),

            // Auto month badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(PortalTokens.radius),
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month,
                      size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Text('الشهر: $month $year',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(width: 6),
                  Text('(تلقائي)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ID Number field with live validation
            Text('هوية المشترك أو هاتفه مع رمز الدولة',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _idCtrl,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'رقم الهوية أو +970…',
                      hintStyle: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                      prefixIcon: Icon(Icons.badge_outlined,
                          size: 20,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
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
                                  _idValid ? Icons.check_circle : Icons.cancel,
                                  color: _idValid
                                      ? PortalTone.success.colors(context).$1
                                      : PortalTone.danger.colors(context).$1,
                                  size: 22)
                              : null,
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(PortalTokens.radius),
                          borderSide: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(PortalTokens.radius),
                          borderSide: BorderSide(
                              color: _idChecked
                                  ? (_idValid
                                      ? PortalTone.success.colors(context).$1
                                      : PortalTone.danger.colors(context).$1)
                                  : Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                              width: _idChecked ? 1.5 : 1)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(PortalTokens.radius),
                          borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2)),
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
                      minimumSize:
                          const Size(PortalTokens.target, PortalTokens.target),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 0),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(PortalTokens.radius)),
                    ),
                    child: const Text('تحقق'),
                  ),
                ),
              ],
            ),

            // ID validation result message
            if (_idChecked) ...[
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (_idValid
                          ? PortalTone.success.colors(context).$1
                          : PortalTone.danger.colors(context).$1)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(PortalTokens.radiusSmall),
                ),
                child: Row(
                  children: [
                    Icon(
                        _idValid ? Icons.person_pin : Icons.person_off_outlined,
                        size: 16,
                        color: _idValid
                            ? PortalTone.success.colors(context).$1
                            : PortalTone.danger.colors(context).$1),
                    const SizedBox(width: 8),
                    Text(
                      _idValid
                          ? 'تم التحقق: $_resolvedName'
                          : 'رقم الهوية غير موجود في النظام',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _idValid
                              ? PortalTone.success.colors(context).$1
                              : PortalTone.danger.colors(context).$1),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Amount field
            Text('قيمة الفاتورة (₪)',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            _SheetField(
                controller: _amountCtrl,
                readOnly: true,
                hint: 'مثال: 280',
                icon: Icons.payments_outlined,
                keyboardType: TextInputType.number),

            const SizedBox(height: 14),

            // kWh field
            Text('الاستهلاك (${billing.valueOrNull?.unitName ?? 'وحدة'})',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _kwhCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _calculateAmount(),
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'مثال: 142.5',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                prefixIcon: Icon(Icons.bolt_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PortalTokens.radius),
                    borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PortalTokens.radius),
                    borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PortalTokens.radius),
                    borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(PortalTokens.radius),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('المبلغ المحسوب:',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(
                    _amountCtrl.text.isEmpty ? '₪ 0' : '₪ ${_amountCtrl.text}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(PortalTokens.radiusPanel)),
                ),
                child: _submitting
                    ? SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Theme.of(context).colorScheme.onPrimary))
                    : Text(canSubmit
                        ? 'إصدار الفاتورة لـ $_resolvedName'
                        : 'تحقق من رقم الهوية أولاً'),
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

  Color _statusColor(BuildContext context) => switch (bill.status) {
        BillStatus.pending => Theme.of(context).colorScheme.primary,
        BillStatus.pendingReview => PortalTone.warning.colors(context).$1,
        BillStatus.paid => PortalTone.success.colors(context).$1,
        BillStatus.rejected => PortalTone.danger.colors(context).$1,
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
    showPortalFormDialog(
      context: context,
      builder: (_) => ReceiptReviewDialog(
        bill: bill,
        subscriberName: _displayName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PortalInvoiceRow(
      title: _displayName,
      period: '${bill.month} ${bill.year}',
      amount: '₪${bill.amount}',
      status: _statusLabel,
      tone: bill.status == BillStatus.paid
          ? PortalTone.success
          : bill.status == BillStatus.rejected
              ? PortalTone.danger
              : PortalTone.warning,
      icon: Icons.receipt_long_outlined,
      accent: _statusColor(context),
      onTap: () => _openReviewDialog(context),
      footer: bill.status == BillStatus.pendingReview
          ? TextButton.icon(
              onPressed: () => _openReviewDialog(context),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('مراجعة سجل الدفع'))
          : null);
}

// ── Complaints Tab ────────────────────────────────────────────────────────────

class _ComplaintsTab extends ConsumerWidget {
  const _ComplaintsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complaintsAsync = ref.watch(complaintsProvider);

    return complaintsAsync.when(
      data: (complaints) => complaints.isEmpty
          ? const _EmptyComplaints()
          : ListView(
              padding: EdgeInsetsDirectional.fromSTEB(
                  PortalTokens.gutter,
                  PortalTokens.lg,
                  PortalTokens.gutter,
                  PortalTokens.navClearance +
                      MediaQuery.paddingOf(context).bottom),
              children: complaints
                  .map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ComplaintCard(item: c),
                      ))
                  .toList(),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const PortalErrorState('تعذّر تحميل الشكاوى'),
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
                color: PortalTone.success.colors(context).$2,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 56,
                color: PortalTone.success.colors(context).$1,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '\u0644\u0627 \u062a\u0648\u062c\u062f \u0634\u0643\u0627\u0648\u064a \u0645\u0639\u0644\u0642\u0629',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: PortalTone.success.colors(context).$1),
            ),
            const SizedBox(height: 10),
            Text(
              '\u062c\u0645\u064a\u0639 \u0627\u0644\u0634\u0643\u0627\u0648\u064a \u062a\u0645\u062a \u0627\u0644\u0645\u0639\u0627\u0644\u062c\u0629 \u0628\u0646\u062c\u0627\u062d. \u0627\u0644\u0646\u0638\u0627\u0645 \u064a\u0639\u0645\u0644 \u0628\u0634\u0643\u0644 \u0637\u0628\u064a\u0639\u064a.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(PortalTokens.radius),
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sentiment_satisfied_alt,
                      size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '\u0627\u0644\u0645\u0634\u062a\u0631\u0643\u0648\n \u0631\u0627\u0636\u064a\u0646 \u0639\u0646 \u0627\u0644\u0645\u0648\u0644\u062f',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary),
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

  Color _color(BuildContext context) => switch (item.status) {
        ComplaintStatus.open => PortalTone.danger.colors(context).$1,
        ComplaintStatus.inProgress => PortalTone.warning.colors(context).$1,
        _ => PortalTone.success.colors(context).$1,
      };

  String get _label => switch (item.status) {
        ComplaintStatus.open => 'مفتوح',
        ComplaintStatus.inProgress => 'قيد المعالجة',
        _ => 'محلول',
      };

  @override
  Widget build(BuildContext context) {
    final hasReply = item.reply != null && item.reply!.isNotEmpty;
    return PortalPanel(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PortalRecordRow(
          title: item.userName,
          subtitle: _timeAgo(item.createdAt),
          icon: Icons.chat_bubble_outline,
          statusLabel: _label,
          statusTone: item.status == ComplaintStatus.resolved
              ? PortalTone.success
              : item.status == ComplaintStatus.inProgress
                  ? PortalTone.warning
                  : PortalTone.danger),
      const SizedBox(height: PortalTokens.md),
      Text(item.text, style: Theme.of(context).textTheme.bodyMedium),
      if (hasReply) ...[
        const Divider(),
        const PortalSection('ردك'),
        Text(item.reply!, style: Theme.of(context).textTheme.bodyMedium)
      ],
      if (item.status != ComplaintStatus.resolved)
        TextButton.icon(
            onPressed: () => _showReplyDialog(context, item.id),
            icon: Icon(Icons.reply_outlined, color: _color(context)),
            label: const Text('الرد على الشكوى')),
    ]));
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return 'قبل ${diff.inDays} يوم';
    if (diff.inHours > 0) return 'قبل ${diff.inHours} ساعة';
    return 'الآن';
  }

  void _showReplyDialog(BuildContext context, String complaintId) {
    final ctrl = TextEditingController();
    showPortalFormDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PortalTokens.radiusPanel)),
          title: const Text('الرد على الشكوى'),
          content: TextField(
            controller: ctrl,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'اكتب ردك هنا...',
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PortalTokens.radius)),
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
                      content:
                          Text('تم إرسال الرد ✓', textAlign: TextAlign.right)));
                }
              },
              style: ElevatedButton.styleFrom(
                  minimumSize:
                      const Size(PortalTokens.target, PortalTokens.target),
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
        data: (s) => s
            .where((u) => u.subscriptionStatus == SubscriptionStatus.active)
            .length,
        loading: () => 0,
        error: (_, __) => 0);
    final totalBills = billsStats.paidCount + billsStats.unpaidCount;

    final joinDate = profile != null
        ? '${profile.createdAt.day}/${profile.createdAt.month}/${profile.createdAt.year}'
        : '—';

    return ListView(
        padding: EdgeInsetsDirectional.fromSTEB(
            PortalTokens.gutter,
            PortalTokens.lg,
            PortalTokens.gutter,
            PortalTokens.navClearance + MediaQuery.paddingOf(context).bottom),
        children: [
          PortalPanel(
              child: Row(children: [
            CircleAvatar(
                radius: PortalTokens.xl,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(initials,
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(color: theme.colorScheme.primary))),
            const SizedBox(width: PortalTokens.lg),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(profile?.name ?? 'صاحب المولد',
                      style: theme.textTheme.titleLarge),
                  Text('صاحب مولد', style: theme.textTheme.bodySmall),
                ]))
          ])),
          const PortalSection('المشتركون والفواتير'),
          PortalPanel(
              child: Column(children: [
            PortalDataRow(
                label: 'المشتركون',
                value: '$totalSubs',
                icon: Icons.people_outline),
            PortalDataRow(
                label: 'نشطون',
                value: '$activeSubs',
                icon: Icons.check_circle_outline),
            PortalDataRow(
                label: 'الفواتير',
                value: '$totalBills',
                icon: Icons.receipt_long_outlined),
          ])),
          const PortalSection('البيانات الشخصية'),
          PortalPanel(
              child: Column(children: [
            PortalDataRow(
                label: 'رقم الهاتف',
                value: profile?.phone.isNotEmpty == true ? profile!.phone : '—',
                icon: Icons.phone_outlined),
            PortalDataRow(
                label: 'العنوان',
                value: profile?.address?.isNotEmpty == true
                    ? profile!.address!
                    : '—',
                icon: Icons.location_on_outlined),
            PortalDataRow(
                label: 'تاريخ الانضمام',
                value: joinDate,
                icon: Icons.calendar_today_outlined),
          ])),
          const PortalSection('إعدادات الحساب'),
          ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('إعدادات الدخول'),
              subtitle: const Text('الهاتف والهوية وكلمة المرور'),
              onTap: () => context.go('/account-security')),
          PortalPanel(
              child: Column(children: [
            ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('تعديل البيانات الشخصية'),
                subtitle: const Text('تغيير الاسم والعنوان'),
                onTap: () => _showEditSheet(context, ref)),
            const Divider(),
            ListTile(
                leading: Icon(isDark
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined),
                title: Text(isDark ? 'الوضع الداكن' : 'الوضع الفاتح'),
                subtitle: Text(isDark
                    ? 'اضغط للتبديل للوضع الفاتح'
                    : 'اضغط للتبديل للوضع الداكن'),
                trailing: Switch(
                    value: isDark,
                    onChanged: (_) =>
                        ref.read(themeProvider.notifier).toggle()),
                onTap: () => ref.read(themeProvider.notifier).toggle()),
          ])),
          const SizedBox(height: PortalTokens.xl),
          OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authProvider.notifier).signOut();
                if (context.mounted) context.go('/login');
              },
              icon: Icon(Icons.logout, color: theme.colorScheme.error),
              label: Text('تسجيل الخروج',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.error))),
          const SizedBox(height: PortalTokens.xl),
          Center(
              child: Text('بوابة المولدات v1.0.0',
                  style: theme.textTheme.bodySmall)),
        ]);
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    final profile = ref.read(authProvider).profile;
    final nameCtrl = TextEditingController(text: profile?.name ?? '');
    final addressCtrl = TextEditingController(text: profile?.address ?? '');
    final phoneCtrl = TextEditingController(text: profile?.phone ?? '');

    showPortalFormSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24,
          ),
          child: SingleChildScrollView(
            child: SingleChildScrollView(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('تعديل بيانات الحساب',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700)),
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
                  readOnly: true,
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
                            await ref.read(authProvider.notifier).updateProfile(
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
                        ? SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Theme.of(context).colorScheme.onPrimary))
                        : const Text('حفظ التغييرات'),
                  );
                }),
              ],
            )),
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
    final pendingAsync = ref.watch(consumerRequestsProvider);

    return pendingAsync.when(
      data: (users) => users.isEmpty
          ? Center(
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
                  Text('لا توجد طلبات للمراجعة',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('جميع الطلبات تمت معالجتها',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsetsDirectional.fromSTEB(
                  PortalTokens.gutter,
                  PortalTokens.lg,
                  PortalTokens.gutter,
                  PortalTokens.navClearance +
                      MediaQuery.paddingOf(context).bottom),
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
              Icon(Icons.error_outline,
                  size: 48, color: PortalTone.warning.colors(context).$1),
              const SizedBox(height: 16),
              Text('تعذّر تحميل الطلبات المعلقة',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(err.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
    final reason = approve
        ? ''
        : await requestRejectionReason(context, title: 'سبب رفض طلب الاشتراك');
    if (reason == null || !mounted) return;
    setState(() => _loading = true);
    try {
      if (approve) {
        await FirebaseService().approveUser(widget.user.uid);
        NotificationService().notifyUserApproved(widget.user.uid);
      } else {
        await FirebaseService().rejectUser(widget.user.uid, reason: reason);
        NotificationService().notifyUserRejected(widget.user.uid);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(approve ? 'تمت الموافقة ✓' : 'تم رفض الطلب',
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
            backgroundColor: PortalTone.danger.colors(context).$1));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return PortalPanel(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PortalRecordRow(
          title: u.name.isNotEmpty ? u.name : 'بدون اسم',
          subtitle: 'بانتظار',
          icon: Icons.person_outline,
          statusLabel:
              u.approvalStatus == ApprovalStatus.rejected ? 'مرفوض' : 'بانتظار',
          statusTone: u.approvalStatus == ApprovalStatus.rejected
              ? PortalTone.danger
              : PortalTone.warning),
      if (u.rejectionReason.isNotEmpty) Text(u.rejectionReason),
      PortalLabelValue(
          label: 'رقم الهوية', value: u.idNumber.isNotEmpty ? u.idNumber : '—'),
      if (u.address.isNotEmpty)
        PortalDataRow(
            label: 'العنوان',
            value: u.address,
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

// ─────────────────────────────────────────────────────────────────────────────
