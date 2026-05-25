import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/alert_model.dart';
import '../../../providers/data_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/firebase_service.dart';
import '../../../config/colors.dart';

class AlertsTab extends ConsumerWidget {
  const AlertsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).profile;
    final alertsAsync = ref.watch(alertsProvider(profile?.uid ?? ''));
    final theme = Theme.of(context);

    final unreadCount = alertsAsync.when(
      data: (alerts) => alerts.where((a) => !a.read).length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                Text('التنبيهات',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(color: Colors.white)),
                const SizedBox(width: 8),
                if (unreadCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('$unreadCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            actions: [
              alertsAsync.when(
                data: (alerts) => alerts.isEmpty
                    ? const SizedBox.shrink()
                    : TextButton(
                        onPressed: () async {
                          final uid = profile?.uid;
                          if (uid == null || uid.isEmpty) return;
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => Directionality(
                              textDirection: TextDirection.rtl,
                              child: AlertDialog(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                title: const Text('مسح جميع التنبيهات؟'),
                                content: const Text(
                                    'سيتم حذف جميع التنبيهات نهائياً.'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('إلغاء')),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.error,
                                        minimumSize: Size.zero,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8)),
                                    child: const Text('مسح الكل'),
                                  ),
                                ],
                              ),
                            ),
                          );
                          if (confirm == true) {
                            await FirebaseService().deleteAllAlerts(uid);
                          }
                        },
                        child: const Text('مسح الكل',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 13)),
                      ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                alertsAsync.when(
                  data: (alerts) => alerts.isEmpty
                      ? const _EmptyAlerts()
                      : Column(
                          children: alerts
                              .map((a) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _AlertCard(alert: a),
                                  ))
                              .toList(),
                        ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const _EmptyAlerts(),
                ),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts();

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.mutedFor(Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none, size: 52, color: muted),
          const SizedBox(height: 12),
          Text('لا توجد تنبيهات',
              style: TextStyle(color: muted, fontSize: 15)),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final AppAlert alert;
  const _AlertCard({required this.alert});

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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: alert.read
            ? Theme.of(context).cardTheme.color
            : _color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: alert.read ? null : Border.all(color: _color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: _color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(_iconFor(alert.type), size: 20, color: _color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(alert.title,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: alert.read
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              )),
                    ),
                    if (!alert.read)
                      Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                              color: _color, shape: BoxShape.circle)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(alert.body,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedFor(
                            Theme.of(context).brightness))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_timeAgo(alert.createdAt),
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.mutedFor(Theme.of(context).brightness))),
        ],
      ),
    ).animate().fadeIn();
  }

  IconData _iconFor(AlertType t) => switch (t) {
        AlertType.generatorOn || AlertType.generatorOff => Icons.power,
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
    if (diff.inDays > 0) return 'قبل ${diff.inDays} يوم';
    if (diff.inHours > 0) return 'قبل ${diff.inHours} ساعة';
    return 'للتو';
  }
}

class _MockAlerts extends StatelessWidget {
  const _MockAlerts();

  static const _items = [
    (Icons.power, AppColors.success, 'تشغيل المولد', 'تم تشغيل المولد',
        'منذ ساعتين', false),
    (Icons.warning_amber, AppColors.warning, 'انتهاء وقود قريباً',
        'متبقي 20% من الوقود', 'منذ 5 ساعات', true),
    (Icons.receipt, AppColors.primary, 'فاتورة جديدة', 'فاتورة يوليو ₪284',
        'أمس', true),
    (Icons.power_off, AppColors.error, 'إيقاف المولد', 'إيقاف مؤقت لصيانة',
        'أمس', true),
    (Icons.check_circle, AppColors.success, 'تأكيد إيصال',
        'تم قبول إيصال يونيو', 'قبل يومين', true),
    (Icons.person_add, AppColors.primary, 'مشترك جديد',
        'تمت إضافة مشترك جديد', 'قبل أسبوع', true),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _items
          .map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: i.$6
                        ? Theme.of(context).cardTheme.color
                        : i.$2.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: i.$6
                        ? null
                        : Border.all(color: i.$2.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: i.$2.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(i.$1, size: 20, color: i.$2),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(i.$3,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: i.$6
                                              ? FontWeight.w500
                                              : FontWeight.w700)),
                                ),
                                if (!i.$6)
                                  Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                          color: i.$2,
                                          shape: BoxShape.circle)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(i.$4,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mutedFor(
                                        Theme.of(context).brightness))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(i.$5,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.mutedFor(
                                  Theme.of(context).brightness))),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}
