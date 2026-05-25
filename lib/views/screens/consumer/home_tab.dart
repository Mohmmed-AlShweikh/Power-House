import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/alert_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../config/colors.dart';
import '../../widgets/notification_bell.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).profile;
    final uid = profile?.uid ?? '';
    final theme = Theme.of(context);

    final genAsync = ref.watch(generatorProvider);
    final isOn = genAsync.when(
        data: (g) => g.isOn, loading: () => true, error: (_, __) => false);
    final lastChanged = genAsync.when(
        data: (g) => g.lastChanged, loading: () => null, error: (_, __) => null);

    final billsAsync = ref.watch(billsProvider(uid));
    final alertsAsync = ref.watch(alertsProvider(uid));
    final consumptionAsync = ref.watch(consumptionProvider(uid));

    final currentMonth = currentMonthArabic();
    final currentYear = DateTime.now().year;

    final currentMonthBill = billsAsync.when(
      data: (bills) {
        final found = bills.where(
            (b) => b.month == currentMonth && b.year == currentYear);
        return found.isNotEmpty ? found.first : null;
      },
      loading: () => null,
      error: (_, __) => null,
    );

    final totalKwh = currentMonthBill != null
        ? '${currentMonthBill.kwh.toStringAsFixed(0)} kWh'
        : billsAsync.when(
            data: (_) => '— kWh',
            loading: () => '… kWh',
            error: (_, __) => '— kWh');

    final billAmount = currentMonthBill != null
        ? '₪ ${currentMonthBill.amount}'
        : billsAsync.when(
            data: (_) => '₪ —',
            loading: () => '₪ …',
            error: (_, __) => '₪ —');

    final dailyKwh = consumptionAsync.when(
        data: (c) =>
            c.dailyUsage > 0 ? '${c.dailyUsage.toStringAsFixed(1)} kWh' : '— kWh',
        loading: () => '… kWh',
        error: (_, __) => '— kWh');

    final ampereLimit = profile?.ampereLimit ?? 0;
    final ampereStr = ampereLimit > 0 ? '$ampereLimit A' : '—';

    final recentAlerts = alertsAsync.when(
      data: (alerts) => alerts.take(3).toList(),
      loading: () => <AppAlert>[],
      error: (_, __) => <AppAlert>[],
    );
    final alertsLoading = alertsAsync.isLoading;

    final unreadCount = alertsAsync.when(
      data: (a) => a.where((x) => !x.read).length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            automaticallyImplyLeading: false,
            actions: [
              Consumer(
                builder: (_, ref, __) {
                  final themeMode = ref.watch(themeProvider);
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          themeMode == ThemeMode.dark
                              ? Icons.light_mode
                              : Icons.dark_mode,
                          color: Colors.white,
                        ),
                        onPressed: () =>
                            ref.read(themeProvider.notifier).toggle(),
                      ),
                      const NotificationBell(),
                      IconButton(
                        tooltip: 'تسجيل الخروج',
                        icon: const Icon(Icons.logout, color: Colors.white),
                        onPressed: () async {
                          await ref.read(authProvider.notifier).signOut();
                          if (context.mounted) context.go('/login');
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      AppColors.primaryDarkFor(Theme.of(context).brightness),
                      AppColors.primaryFor(Theme.of(context).brightness),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.35),
                                width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              (profile?.name.isNotEmpty == true)
                                  ? profile!.name[0]
                                  : '؟',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Greeting
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _greeting(),
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.75),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                profile?.name ?? 'زائر',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if ((profile?.address ?? '').isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.location_on,
                                          size: 11,
                                          color: Colors.white.withOpacity(0.6)),
                                      const SizedBox(width: 3),
                                      Text(
                                        profile!.address,
                                        style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.65),
                                            fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _GeneratorStatusCard(isOn: isOn, lastChanged: lastChanged),
                const SizedBox(height: 16),

                Text('الاستهلاك الشهري ($currentMonth)',
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatCard(
                        label: 'هذا الشهر',
                        value: totalKwh,
                        icon: Icons.flash_on,
                        color: AppColors.primary),
                    const SizedBox(width: 12),
                    _StatCard(
                        label: 'الفاتورة',
                        value: billAmount,
                        icon: Icons.receipt_long,
                        color: AppColors.warning),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatCard(
                        label: 'حد الأمبير',
                        value: ampereStr,
                        icon: Icons.electric_bolt_outlined,
                        color: AppColors.success),
                    const SizedBox(width: 12),
                    _StatCard(
                        label: 'الاستهلاك اليومي',
                        value: dailyKwh,
                        icon: Icons.today_outlined,
                        color: const Color(0xFF8B5CF6)),
                  ],
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Text('آخر التنبيهات', style: theme.textTheme.titleLarge),
                    const Spacer(),
                    if (unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(10)),
                        child: Text('$unreadCount',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (alertsLoading)
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  ))
                else if (recentAlerts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.notifications_none,
                            color: AppColors.mutedFor(
                                Theme.of(context).brightness),
                            size: 20),
                        const SizedBox(width: 10),
                        Text('لا توجد تنبيهات',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.mutedFor(
                                    Theme.of(context).brightness))),
                      ],
                    ),
                  )
                else
                  ...recentAlerts
                      .map((a) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _AlertItem(alert: a),
                          ))
                      .toList(),

                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

String _greeting() {
  final h = DateTime.now().hour;
  if (h >= 5 && h < 12) return 'صباح الخير 🌤';
  if (h >= 12 && h < 17) return 'مساء النور 🌞';
  if (h >= 17 && h < 21) return 'مساء الخير 🌆';
  return 'تصبح على خير 🌙';
}

class _GeneratorStatusCard extends StatelessWidget {
  final bool isOn;
  final DateTime? lastChanged;
  const _GeneratorStatusCard({required this.isOn, this.lastChanged});

  String _runningFor() {
    if (!isOn) return '';
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
                .withOpacity(0.35),
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
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bolt, color: Colors.white, size: 32),
          ).animate().fadeIn().scaleXY(
              begin: 0.8, end: 1, duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isOn ? 'المولد يعمل الآن' : 'المولد متوقف',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                if (isOn) ...[
                  const SizedBox(height: 2),
                  Text(_runningFor(),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 8, color: Colors.white),
                const SizedBox(width: 5),
                Text(isOn ? 'نشط' : 'موقف',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color:
                        AppColors.mutedFor(Theme.of(context).brightness))),
          ],
        ),
      ).animate().fadeIn().slideY(begin: 0.2, end: 0, duration: 300.ms),
    );
  }
}

class _AlertItem extends StatelessWidget {
  final AppAlert alert;
  const _AlertItem({required this.alert});

  Color get _color => switch (alert.type) {
        AlertType.generatorOn => AppColors.success,
        AlertType.generatorOff => AppColors.error,
        AlertType.lowFuel => AppColors.warning,
        AlertType.newBill => AppColors.primary,
        AlertType.receiptApproved => AppColors.success,
        AlertType.receiptRejected => AppColors.error,
        AlertType.newSubscriber => AppColors.primary,
        AlertType.complaint => AppColors.warning,
        AlertType.newOwnerRequest => AppColors.primary,
        AlertType.newConsumerRequest => AppColors.primary,
        AlertType.requestApproved => AppColors.success,
        AlertType.requestRejected => AppColors.error,
        AlertType.passwordReset => AppColors.warning,
      };

  IconData get _icon => switch (alert.type) {
        AlertType.generatorOn => Icons.power,
        AlertType.generatorOff => Icons.power_off,
        AlertType.lowFuel => Icons.local_gas_station,
        AlertType.newBill => Icons.receipt,
        AlertType.receiptApproved => Icons.check_circle,
        AlertType.receiptRejected => Icons.cancel,
        AlertType.newSubscriber => Icons.person_add,
        AlertType.complaint => Icons.report,
        AlertType.newOwnerRequest => Icons.person_add_alt_1,
        AlertType.newConsumerRequest => Icons.person_add,
        AlertType.requestApproved => Icons.check_circle,
        AlertType.requestRejected => Icons.cancel,
        AlertType.passwordReset => Icons.lock_reset,
      };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 1) return 'قبل ${diff.inDays} أيام';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inHours > 1) return 'قبل ${diff.inHours} ساعات';
    if (diff.inHours == 1) return 'قبل ساعة';
    if (diff.inMinutes > 1) return 'قبل ${diff.inMinutes} دقائق';
    return 'الآن';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: alert.read
            ? Theme.of(context).cardTheme.color
            : _color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border:
            alert.read ? null : Border.all(color: _color.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: _color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, size: 18, color: _color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: alert.read
                            ? FontWeight.w600
                            : FontWeight.w700,
                        )),
                const SizedBox(height: 2),
                Text(alert.body,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedFor(
                            Theme.of(context).brightness))),
              ],
            ),
          ),
          Text(_timeAgo(alert.createdAt),
              style: TextStyle(
                  fontSize: 11,
                  color:
                      AppColors.mutedFor(Theme.of(context).brightness))),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.1, end: 0, duration: 300.ms);
  }
}
