import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/alert_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../services/firebase_service.dart';
import '../../config/colors.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authProvider).profile?.uid ?? '';
    final alertsAsync = ref.watch(alertsProvider(uid));
    final unread = alertsAsync.when(
      data: (a) => a.where((x) => !x.read).length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    return IconButton(
      onPressed: () => _open(context, ref, uid),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
          if (unread > 0)
            Positioned(
              top: -4,
              left: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ).animate().scale(
                    duration: 250.ms,
                    curve: Curves.elasticOut,
                    begin: const Offset(0.4, 0.4),
                    end: const Offset(1, 1),
                  ),
            ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, String uid) async {
    if (uid.isNotEmpty) {
      FirebaseService().markAllAlertsRead(uid);
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _NotificationsSheet(uid: uid),
      ),
    );
  }
}

class _NotificationsSheet extends ConsumerWidget {
  final String uid;
  const _NotificationsSheet({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsProvider(uid));
    final brightness = Theme.of(context).brightness;
    final surface = brightness == Brightness.dark
        ? AppColors.darkSurface
        : Colors.white;
    final bg = brightness == Brightness.dark
        ? AppColors.darkBackground
        : AppColors.lightBackground;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.mutedFor(brightness).withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryFor(brightness).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.notifications,
                        color: AppColors.primaryFor(brightness), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'الإشعارات',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textFor(brightness),
                    ),
                  ),
                  const Spacer(),
                  alertsAsync.maybeWhen(
                    data: (alerts) => alerts.isNotEmpty
                        ? TextButton(
                            onPressed: () async {
                              if (uid.isEmpty) return;
                              await FirebaseService().deleteAllAlerts(uid);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.error,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                            ),
                            child: const Text('مسح الكل',
                                style: TextStyle(fontSize: 13)),
                          )
                        : const SizedBox.shrink(),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.mutedFor(brightness).withOpacity(0.15)),
            // List
            Expanded(
              child: alertsAsync.when(
                data: (alerts) => alerts.isEmpty
                    ? _EmptyState(brightness: brightness)
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        itemCount: alerts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _SheetAlertCard(
                          alert: alerts[i],
                          surface: surface,
                          brightness: brightness,
                        ).animate().fadeIn(
                              delay: Duration(milliseconds: i * 40),
                              duration: 300.ms,
                            ),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => _EmptyState(brightness: brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Brightness brightness;
  const _EmptyState({required this.brightness});

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.mutedFor(brightness);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded, size: 56, color: muted),
          const SizedBox(height: 12),
          Text('لا توجد إشعارات',
              style: TextStyle(color: muted, fontSize: 15)),
        ],
      ),
    );
  }
}

class _SheetAlertCard extends StatelessWidget {
  final AppAlert alert;
  final Color surface;
  final Brightness brightness;
  const _SheetAlertCard(
      {required this.alert,
      required this.surface,
      required this.brightness});

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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _color.withOpacity(0.18),
          width: 1,
        ),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: _color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(_icon, size: 20, color: _color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textFor(brightness))),
                const SizedBox(height: 3),
                Text(alert.body,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedFor(brightness))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_timeAgo(alert.createdAt),
                  style: TextStyle(
                      fontSize: 10,
                      color: AppColors.mutedFor(brightness))),
              const SizedBox(height: 4),
              if (!alert.read)
                Container(
                  width: 7,
                  height: 7,
                  decoration:
                      BoxDecoration(color: _color, shape: BoxShape.circle),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
