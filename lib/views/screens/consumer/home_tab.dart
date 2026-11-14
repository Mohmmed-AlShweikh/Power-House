import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/alert_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../theme/portal_tokens.dart';
import '../../../theme/portal_theme.dart';
import '../../widgets/portal_components.dart';
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

    final billsAsync = ref.watch(billsProvider(uid));
    final alertsAsync = ref.watch(alertsProvider(uid));
    final consumptionAsync = ref.watch(consumptionProvider(uid));

    final currentMonth = currentMonthArabic();
    final currentYear = DateTime.now().year;

    final currentMonthBill = billsAsync.when(
      data: (bills) {
        final found = bills
            .where((b) => b.month == currentMonth && b.year == currentYear);
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
            data: (_) => '₪ —', loading: () => '₪ …', error: (_, __) => '₪ —');

    final dailyKwh = consumptionAsync.when(
        data: (c) => c.dailyUsage > 0
            ? '${c.dailyUsage.toStringAsFixed(1)} kWh'
            : '— kWh',
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

    return Theme(
      data: buildPortalTheme(theme.brightness),
      child: Builder(builder: (context) {
        final palette = Theme.of(context).colorScheme;
        return Scaffold(
            body: Column(children: [
          PortalIdentityBar(
              title: 'بوابة المولدات',
              subtitle: profile?.name ?? 'زائر',
              actions: [
                IconButton(
                    tooltip: 'تبديل المظهر',
                    icon: Icon(theme.brightness == Brightness.dark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined),
                    onPressed: () => ref.read(themeProvider.notifier).toggle()),
                NotificationBell(iconColor: palette.onSurface),
                IconButton(
                    tooltip: 'تسجيل الخروج',
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      await ref.read(authProvider.notifier).signOut();
                      if (context.mounted) context.go('/login');
                    }),
              ]),
          Expanded(
              child: ListView(padding: PortalTokens.pagePadding, children: [
            Text(_greeting(), style: Theme.of(context).textTheme.titleLarge),
            if ((profile?.address ?? '').isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: PortalTokens.xs),
                  child: Text(profile!.address,
                      style: Theme.of(context).textTheme.bodySmall)),
            const SizedBox(height: PortalTokens.lg),
            _GeneratorStatusCard(
                isOn: isOn,
                lastChanged: lastChanged,
                scheduledOnAt: scheduledOnAt,
                scheduledOffAt: scheduledOffAt),
            PortalSection('الاستهلاك الشهري ($currentMonth)'),
            PortalMetricPair(
                first: PortalMetric(
                    label: 'هذا الشهر',
                    value: totalKwh,
                    icon: Icons.electric_bolt_outlined),
                second: PortalMetric(
                    label: 'الفاتورة',
                    value: billAmount,
                    icon: Icons.receipt_long_outlined)),
            const SizedBox(height: PortalTokens.md),
            PortalMetricPair(
                first: PortalMetric(
                    label: 'حد الأمبير',
                    value: ampereStr,
                    icon: Icons.speed_outlined),
                second: PortalMetric(
                    label: 'سعر kWh',
                    value: '₪ ${currentPrice.toStringAsFixed(2)}',
                    icon: Icons.payments_outlined)),
            const SizedBox(height: PortalTokens.md),
            PortalMetric(
                label: 'الاستهلاك اليومي',
                value: dailyKwh,
                icon: Icons.today_outlined),
            PortalSection('آخر التنبيهات',
                trailing: unreadCount > 0
                    ? PortalStatusChip(
                        label: '$unreadCount',
                        tone: PortalTone.warning,
                        icon: Icons.notifications_outlined)
                    : null),
            PortalPanel(
                child: alertsLoading
                    ? const PortalLoadingState()
                    : recentAlerts.isEmpty
                        ? const PortalEmptyState('لا توجد تنبيهات',
                            icon: Icons.notifications_none)
                        : Column(
                            children: recentAlerts
                                .map((a) => _AlertItem(alert: a))
                                .toList())),
          ])),
        ]));
      }),
    );
  }
}

String _greeting() {
  final h = DateTime.now().hour;
  if (h >= 5 && h < 12) return 'صباح الخير';
  if (h >= 12 && h < 17) return 'مساء النور';
  if (h >= 17 && h < 21) return 'مساء الخير';
  return 'تصبح على خير';
}

class _GeneratorStatusCard extends StatelessWidget {
  final bool isOn;
  final DateTime? lastChanged;
  final DateTime? scheduledOnAt;
  final DateTime? scheduledOffAt;
  const _GeneratorStatusCard({
    required this.isOn,
    this.lastChanged,
    this.scheduledOnAt,
    this.scheduledOffAt,
  });

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

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) => PortalGeneratorPanel(
        isOn: isOn,
        detail: isOn ? _runningFor() : 'المولد متوقف',
        schedule: scheduledOnAt != null || scheduledOffAt != null
            ? 'الجدول: ${scheduledOnAt != null ? _formatTime(scheduledOnAt!) : 'غير محدد'} - ${scheduledOffAt != null ? _formatTime(scheduledOffAt!) : 'غير محدد'}'
            : null,
      );
}

class _AlertItem extends StatelessWidget {
  final AppAlert alert;
  const _AlertItem({required this.alert});

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
  Widget build(BuildContext context) => PortalRecordRow(
        title: alert.title,
        subtitle: alert.body,
        icon: _icon,
        trailing: _timeAgo(alert.createdAt),
      );
}
