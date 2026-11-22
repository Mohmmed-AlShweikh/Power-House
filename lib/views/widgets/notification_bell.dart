import 'portal_keyboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/alert_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../services/firebase_service.dart';
import 'portal_components.dart';
import '../../theme/portal_tokens.dart';

class NotificationBell extends ConsumerWidget {
  final Color? iconColor;
  const NotificationBell({super.key, this.iconColor});

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
      tooltip: 'الإشعارات',
      onPressed: () => _open(context, ref, uid),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.notifications_outlined,
              color: iconColor ?? Theme.of(context).colorScheme.onSurface,
              size: 24),
          if (unread > 0)
            Positioned(
              top: -4,
              left: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onError,
                      ),
                  textAlign: TextAlign.center,
                ),
              ).animate().fadeIn(duration: PortalTokens.motion),
            ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, String uid) async {
    if (uid.isNotEmpty) {
      FirebaseService().markAllAlertsRead(uid);
    }
    await showPortalFormSheet(
      context: context,
      scrollable: false,
      isScrollControlled: true,
      backgroundColor: PortalTokens.transparent,
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
    return DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) => Container(
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(PortalTokens.radiusSheet))),
            child: Column(children: [
              const SizedBox(height: PortalTokens.md),
              Padding(
                  padding: PortalTokens.panelPadding,
                  child: Row(children: [
                    Icon(Icons.notifications_outlined,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: PortalTokens.md),
                    Expanded(
                        child: Text('الإشعارات',
                            style: Theme.of(context).textTheme.titleLarge)),
                    alertsAsync.maybeWhen(
                        data: (alerts) => alerts.isNotEmpty
                            ? TextButton(
                                onPressed: () async {
                                  if (uid.isEmpty) return;
                                  await FirebaseService().deleteAllAlerts(uid);
                                },
                                style: TextButton.styleFrom(
                                    foregroundColor:
                                        Theme.of(context).colorScheme.error),
                                child: const Text('مسح الكل'))
                            : const SizedBox.shrink(),
                        orElse: () => const SizedBox.shrink()),
                  ])),
              const Divider(height: PortalTokens.line),
              Expanded(
                  child: alertsAsync.when(
                data: (alerts) => alerts.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: PortalTokens.pagePadding,
                        itemCount: alerts.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: PortalTokens.md),
                        itemBuilder: (_, i) =>
                            _SheetAlertCard(alert: alerts[i])),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const _EmptyState(),
              )),
            ])));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
      child: PortalEmptyState('لا توجد إشعارات',
          icon: Icons.notifications_none_rounded));
}

class _SheetAlertCard extends StatelessWidget {
  final AppAlert alert;
  const _SheetAlertCard({required this.alert});
  PortalTone get _tone => switch (alert.type) {
        AlertType.generatorOn => PortalTone.working,
        AlertType.generatorOff => PortalTone.stopped,
        AlertType.receiptApproved ||
        AlertType.requestApproved =>
          PortalTone.success,
        AlertType.receiptRejected ||
        AlertType.requestRejected =>
          PortalTone.danger,
        _ => PortalTone.warning,
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
  Widget build(BuildContext context) => PortalRecordRow(
      title: alert.title,
      subtitle: alert.body,
      icon: _icon,
      trailing: _timeAgo(alert.createdAt),
      statusLabel: alert.read ? 'مقروء' : 'جديد',
      statusTone: _tone);
}
