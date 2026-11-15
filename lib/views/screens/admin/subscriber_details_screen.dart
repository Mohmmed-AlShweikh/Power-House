import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/portal_tokens.dart';
import '../../widgets/portal_components.dart';
import '../../widgets/portal_number.dart';
import '../../../models/bill_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/data_provider.dart';
import '../../widgets/base64_image_viewer.dart';
import '../../../services/firebase_service.dart';
import '../../../services/notification_service.dart';

class SubscriberDetailsScreen extends ConsumerWidget {
  final UserProfile sub;
  final void Function(String billId) onJumpToBill;

  const SubscriberDetailsScreen({
    super.key,
    required this.sub,
    required this.onJumpToBill,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(billsProvider(sub.uid));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          elevation: 0,
          title: Text(
            sub.name.isNotEmpty ? sub.name : 'تفاصيل المشترك',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          leading: const BackButton(),
        ),
        body: billsAsync.when(
          data: (bills) => _buildBody(context, bills),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _buildBody(context, []),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<Bill> bills) {
    final pendingReview =
        bills.where((b) => b.status == BillStatus.pendingReview).toList();
    final due = bills.where((b) => b.status == BillStatus.pending).toList();
    final paid = bills.where((b) => b.status == BillStatus.paid).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SubInfoCard(sub: sub),
        const SizedBox(height: 20),
        if (pendingReview.isNotEmpty) ...[
          _SectionHeader(
            title: 'طلبات الدفع المعلقة',
            count: pendingReview.length,
            color: PortalTone.warning.colors(context).$1,
            icon: Icons.pending_actions,
          ),
          const SizedBox(height: 8),
          ...pendingReview.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PaymentRequestCard(
                  bill: b,
                  onView: () {
                    Navigator.pop(context);
                    onJumpToBill(b.id);
                  },
                ),
              )),
          const SizedBox(height: 8),
        ],
        _SectionHeader(
          title: 'الفواتير المستحقة',
          count: due.length,
          color: PortalTone.danger.colors(context).$1,
          icon: Icons.receipt_long,
        ),
        const SizedBox(height: 8),
        if (due.isEmpty)
          const _EmptyBills(message: 'لا يوجد فواتير مستحقة عليه')
        else
          ...due.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BillInfoCard(
                    bill: b, color: PortalTone.danger.colors(context).$1),
              )),
        const SizedBox(height: 16),
        _SectionHeader(
          title: 'الفواتير المدفوعة',
          count: paid.length,
          color: PortalTone.success.colors(context).$1,
          icon: Icons.check_circle_outline,
        ),
        const SizedBox(height: 8),
        if (paid.isEmpty)
          const _EmptyBills(message: 'لا توجد فواتير مدفوعة بعد')
        else
          ...paid.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BillInfoCard(
                    bill: b, color: PortalTone.success.colors(context).$1),
              )),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SubInfoCard extends StatelessWidget {
  final UserProfile sub;
  const _SubInfoCard({required this.sub});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = sub.subscriptionStatus == SubscriptionStatus.active;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(PortalTokens.radiusPanel),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            child: Text(
              sub.name.isNotEmpty ? sub.name[0] : '؟',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sub.name.isNotEmpty ? sub.name : 'بدون اسم',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                if (sub.phone.isNotEmpty)
                  Row(children: [
                    Icon(Icons.phone,
                        size: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(sub.phone,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ]),
                if (sub.address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.location_on_outlined,
                        size: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(sub.address,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                    ),
                  ]),
                ],
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(PortalTokens.radius),
                  ),
                  child: Text('${sub.ampereLimit} أمبير',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (isActive
                      ? PortalTone.success.colors(context).$1
                      : PortalTone.danger.colors(context).$1)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(PortalTokens.radiusPanel),
            ),
            child: Text(
              isActive ? 'نشط' : 'موقوف',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? PortalTone.success.colors(context).$1
                      : PortalTone.danger.colors(context).$1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;
  const _SectionHeader(
      {required this.title,
      required this.count,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(PortalTokens.radiusSmall),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(PortalTokens.radius),
          ),
          child: Text('$count',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700, color: color)),
        ),
      ],
    );
  }
}

class _PaymentRequestCard extends StatelessWidget {
  final Bill bill;
  final VoidCallback onView;
  const _PaymentRequestCard({required this.bill, required this.onView});

  @override
  Widget build(BuildContext context) => PortalInvoiceRow(
      title: '${bill.month} ${bill.year}',
      amount: '₪${bill.amount}',
      status: 'إيصال بانتظار المراجعة',
      tone: PortalTone.warning,
      icon: Icons.pending_actions_outlined,
      footer: ElevatedButton(onPressed: onView, child: const Text('مراجعة')));
}

class _BillInfoCard extends StatelessWidget {
  final Bill bill;
  final Color color;
  const _BillInfoCard({required this.bill, required this.color});

  @override
  Widget build(BuildContext context) {
    final isPaid = bill.status == BillStatus.paid;
    return PortalInvoiceRow(
        title: '${bill.month} ${bill.year}',
        amount: '₪${bill.amount}',
        note: '${bill.kwh.toStringAsFixed(1)} كيلوواط',
        status: isPaid ? 'مدفوع' : 'غير مدفوع',
        tone: isPaid ? PortalTone.success : PortalTone.danger,
        accent: color,
        icon:
            isPaid ? Icons.check_circle_outline : Icons.receipt_long_outlined);
  }
}

class _EmptyBills extends StatelessWidget {
  final String message;
  const _EmptyBills({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: PortalTone.success.colors(context).$1.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(PortalTokens.radius),
        border: Border.all(
            color:
                PortalTone.success.colors(context).$1.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline,
              size: 18, color: PortalTone.success.colors(context).$1),
          const SizedBox(width: 10),
          Text(message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: PortalTone.success.colors(context).$1,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class ReceiptReviewDialog extends ConsumerStatefulWidget {
  final Bill bill;
  final String subscriberName;
  const ReceiptReviewDialog(
      {super.key, required this.bill, required this.subscriberName});

  @override
  ConsumerState<ReceiptReviewDialog> createState() =>
      _ReceiptReviewDialogState();
}

class _ReceiptReviewDialogState extends ConsumerState<ReceiptReviewDialog> {
  bool _loading = false;

  Future<void> _act(BillStatus status) async {
    setState(() => _loading = true);
    try {
      await FirebaseService().updateBillStatus(widget.bill.id, status);
      if (status == BillStatus.paid) {
        await NotificationService().addAlert(
          userId: widget.bill.userId,
          title: 'تم قبول الإيصال ✓',
          body:
              'تم قبول إيصال الدفع لفاتورة ${widget.bill.month} ${widget.bill.year} بنجاح.',
          type: 'receiptApproved',
        );
      } else {
        await NotificationService().addAlert(
          userId: widget.bill.userId,
          title: 'تم رفض الإيصال',
          body:
              'تم رفض إيصال الدفع لفاتورة ${widget.bill.month} ${widget.bill.year}. يرجى التواصل مع المشرف.',
          type: 'receiptRejected',
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PortalTokens.radiusPanel)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: PortalTone.warning.colors(context).$2,
                      borderRadius: BorderRadius.circular(PortalTokens.radius),
                    ),
                    child: Icon(Icons.receipt,
                        size: 20, color: PortalTone.warning.colors(context).$1),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.subscriberName,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        PortalNumber('${widget.bill.month} ${widget.bill.year}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: PortalTokens.target,
                        minHeight: PortalTokens.target),
                  ),
                ],
              ),
              PortalLabelValue(
                  label: 'المبلغ',
                  value: '₪${widget.bill.amount}',
                  prominent: true),
              const SizedBox(height: 16),
              if (widget.bill.receiptBase64 != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(PortalTokens.radius),
                  child: Base64ImageViewer(
                      base64String: widget.bill.receiptBase64!, height: 220),
                ),
                const SizedBox(height: 16),
              ] else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(PortalTokens.radius),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.image_not_supported,
                          size: 36,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text('لا توجد صورة إيصال',
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
              const SizedBox(height: 4),
              if (_loading)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(),
                ))
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _act(BillStatus.rejected),
                        icon: const Icon(Icons.close, size: 16),
                        label: Text('رفض',
                            style: Theme.of(context).textTheme.bodySmall),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: PortalTone.danger.colors(context).$1,
                          side: BorderSide(
                              color: PortalTone.danger.colors(context).$1),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(PortalTokens.radius)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _act(BillStatus.paid),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('قبول'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          minimumSize: const Size(
                              PortalTokens.target, PortalTokens.target),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(PortalTokens.radius)),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
