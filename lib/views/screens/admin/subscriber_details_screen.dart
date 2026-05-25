import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/colors.dart';
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
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            sub.name.isNotEmpty ? sub.name : 'تفاصيل المشترك',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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
            color: AppColors.warning,
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
          color: AppColors.error,
          icon: Icons.receipt_long,
        ),
        const SizedBox(height: 8),
        if (due.isEmpty)
          const _EmptyBills(message: 'لا يوجد فواتير مستحقة عليه')
        else
          ...due.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BillInfoCard(bill: b, color: AppColors.error),
              )),
        const SizedBox(height: 16),

        _SectionHeader(
          title: 'الفواتير المدفوعة',
          count: paid.length,
          color: AppColors.success,
          icon: Icons.check_circle_outline,
        ),
        const SizedBox(height: 8),
        if (paid.isEmpty)
          const _EmptyBills(message: 'لا توجد فواتير مدفوعة بعد')
        else
          ...paid.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BillInfoCard(bill: b, color: AppColors.success),
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
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: Text(
              sub.name.isNotEmpty ? sub.name[0] : '؟',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sub.name.isNotEmpty ? sub.name : 'بدون اسم',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                if (sub.phone.isNotEmpty)
                  Row(children: [
                    const Icon(Icons.phone,
                        size: 12, color: AppColors.lightMuted),
                    const SizedBox(width: 4),
                    Text(sub.phone,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.lightMuted)),
                  ]),
                if (sub.address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 12, color: AppColors.lightMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(sub.address,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.lightMuted)),
                    ),
                  ]),
                ],
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${sub.ampereLimit} أمبير',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (isActive ? AppColors.success : AppColors.error)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isActive ? 'نشط' : 'موقوف',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppColors.success : AppColors.error),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0, duration: 300.ms);
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
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color)),
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.4), width: 1.5),
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
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.receipt, size: 20, color: AppColors.warning),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${bill.month} ${bill.year}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('₪${bill.amount} • إيصال بانتظار المراجعة',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.lightMuted)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onView,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: Size.zero,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('مراجعة',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                SizedBox(width: 2),
                Icon(Icons.chevron_left, size: 16, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.05, end: 0, duration: 250.ms);
  }
}

class _BillInfoCard extends StatelessWidget {
  final Bill bill;
  final Color color;
  const _BillInfoCard({required this.bill, required this.color});

  @override
  Widget build(BuildContext context) {
    final isPaid = bill.status == BillStatus.paid;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
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
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
                isPaid ? Icons.check_circle_outline : Icons.receipt_long,
                size: 20,
                color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${bill.month} ${bill.year}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('₪${bill.amount} • ${bill.kwh.toStringAsFixed(1)} كيلوواط',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.lightMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isPaid ? 'مدفوعة' : 'مستحقة',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
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
        color: AppColors.success.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              size: 18, color: AppColors.success),
          const SizedBox(width: 10),
          Text(message,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.success,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    ).animate().fadeIn();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt,
                        size: 20, color: AppColors.warning),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.subscriberName,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        Text(
                            '${widget.bill.month} ${widget.bill.year} • ₪${widget.bill.amount}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.lightMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.bill.receiptBase64 != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Base64ImageViewer(
                      base64String: widget.bill.receiptBase64!, height: 220),
                ),
                const SizedBox(height: 16),
              ] else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    color: AppColors.lightMuted.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.image_not_supported,
                          size: 36, color: AppColors.lightMuted),
                      SizedBox(height: 8),
                      Text('لا توجد صورة إيصال',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.lightMuted)),
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
                        label: const Text('رفض',
                            style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _act(BillStatus.paid),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('قبول',
                            style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(vertical: 10),
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
      ),
    );
  }
}
