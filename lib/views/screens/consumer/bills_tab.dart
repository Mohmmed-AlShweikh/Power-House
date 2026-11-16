import '../../widgets/payment_form.dart';
import '../../widgets/portal_number.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/bill_model.dart';
import '../../../providers/data_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../theme/portal_tokens.dart';
import '../../widgets/portal_components.dart';
import '../../widgets/portal_keyboard.dart';
import '../../widgets/notification_bell.dart';

class BillsTab extends ConsumerWidget {
  const BillsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).profile;
    final uid = profile?.uid ?? '';
    final billsAsync = ref.watch(billsProvider(uid));

    return PortalPage(
        title: 'الفواتير',
        subtitle: 'الفواتير وسجلات الدفع',
        actions: const [
          NotificationBell()
        ],
        children: [
          billsAsync.when(
            data: (bills) {
              final actionable = bills
                  .where((b) =>
                      b.status == BillStatus.pending ||
                      b.status == BillStatus.rejected)
                  .toList();
              if (actionable.isEmpty) return const SizedBox.shrink();
              return _PendingBanner(bill: actionable.first, uid: uid);
            },
            loading: () => const _PendingBannerSkeleton(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const PortalSection('سجل الفواتير'),
          billsAsync.when(
            data: (bills) => bills.isEmpty
                ? const _EmptyBills()
                : Column(
                    children: bills
                        .map((b) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: PortalTokens.md),
                            child: _BillCard(bill: b, uid: uid)))
                        .toList()),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const _EmptyBills(),
          ),
        ]);
  }
}

// ── Pending Banner ─────────────────────────────────────────────────────────────

class _PendingBanner extends StatelessWidget {
  final Bill bill;
  final String uid;
  const _PendingBanner({required this.bill, required this.uid});

  @override
  Widget build(BuildContext context) {
    final isRejected = bill.status == BillStatus.rejected;
    final tone = isRejected ? PortalTone.danger : PortalTone.warning;
    final (ink, fill) = tone.colors(context);
    return PortalPanel(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(isRejected ? Icons.cancel_outlined : Icons.receipt_long,
            color: ink),
        const SizedBox(width: PortalTokens.md),
        Expanded(
            child: PortalNumber(
                isRejected
                    ? 'تم رفض سجل دفع ${bill.month} ${bill.year}'
                    : 'فاتورة ${bill.month} ${bill.year} غير مدفوعة',
                style: Theme.of(context).textTheme.titleMedium)),
      ]),
      const SizedBox(height: PortalTokens.md),
      DecoratedBox(
          decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(PortalTokens.radiusSmall)),
          child: Padding(
              padding: PortalTokens.panelPadding,
              child: isRejected
                  ? Text('راجع سبب الرفض وصحح بيانات الدفع',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: ink))
                  : PortalLabelValue(
                      label: 'المبلغ المستحق',
                      value: '₪${bill.amount}',
                      ink: ink,
                      prominent: true))),
      const SizedBox(height: PortalTokens.lg),
      ElevatedButton.icon(
          onPressed: () {
            showPortalFormSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => PaymentForm(bill: bill));
          },
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(isRejected ? 'إعادة إرسال' : 'تسجيل دفعة')),
    ]));
  }
}

class _PendingBannerSkeleton extends StatelessWidget {
  const _PendingBannerSkeleton();
  @override
  Widget build(BuildContext context) => const PortalPanel(
      child: Padding(
          padding: PortalTokens.pagePadding,
          child: Center(child: CircularProgressIndicator())));
}

// ── Bill Card ─────────────────────────────────────────────────────────────────

class _EmptyBills extends StatelessWidget {
  const _EmptyBills();
  @override
  Widget build(BuildContext context) =>
      const PortalEmptyState('لا توجد فواتير بعد',
          icon: Icons.receipt_long_outlined);
}

class _BillCard extends StatelessWidget {
  final Bill bill;
  final String uid;
  const _BillCard({required this.bill, required this.uid});
  @override
  Widget build(BuildContext context) {
    final isPaid = bill.status == BillStatus.paid;
    final isPendingReview = bill.status == BillStatus.pendingReview;
    final isPending = bill.status == BillStatus.pending;
    final isRejected = bill.status == BillStatus.rejected;
    final canUpload = isPending || isRejected;
    final statusTone = isPaid
        ? PortalTone.success
        : isPendingReview
            ? PortalTone.warning
            : PortalTone.danger;
    String statusLabel = isPaid
        ? 'مدفوعة'
        : isPendingReview
            ? 'بانتظار المراجعة'
            : isRejected
                ? 'مرفوضة'
                : 'غير مدفوعة';
    return PortalInvoiceRow(
        title: '${bill.month} ${bill.year}',
        amount: '₪${bill.amount}',
        status: statusLabel,
        tone: statusTone,
        icon: isPaid
            ? Icons.check_circle_outline
            : isPendingReview
                ? Icons.pending_outlined
                : isRejected
                    ? Icons.cancel_outlined
                    : Icons.error_outline,
        note: isRejected
            ? (bill.reviewReason.isNotEmpty
                ? bill.reviewReason
                : 'اضغط لتصحيح بيانات الدفع')
            : null,
        onTap: canUpload
            ? () => showPortalFormSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => PaymentForm(bill: bill))
            : null);
  }
}
