import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/bill_model.dart';
import '../../../providers/data_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/firebase_service.dart';
import '../../../theme/portal_tokens.dart';
import '../../widgets/portal_components.dart';
import '../../widgets/portal_keyboard.dart';
import '../../widgets/portal_number.dart';
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
        subtitle: 'الفواتير وإيصالات الدفع',
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
                    ? 'تم رفض وصل ${bill.month} ${bill.year}'
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
                  ? Text('يرجى إعادة رفع الوصل الصحيح',
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
                builder: (_) => _UploadReceiptSheet(uid: uid, bill: bill));
          },
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(isRejected ? 'إعادة إرسال' : 'ارسال وصل')),
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

// ── Upload Receipt Sheet ───────────────────────────────────────────────────────

class _UploadReceiptSheet extends ConsumerStatefulWidget {
  final String uid;
  final Bill bill;
  const _UploadReceiptSheet({required this.uid, required this.bill});

  @override
  ConsumerState<_UploadReceiptSheet> createState() =>
      _UploadReceiptSheetState();
}

class _UploadReceiptSheetState extends ConsumerState<_UploadReceiptSheet> {
  Uint8List? _bytes;
  bool _uploading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => _bytes = bytes);
  }

  Future<void> _upload() async {
    if (_bytes == null) return;
    setState(() => _uploading = true);
    try {
      await FirebaseService().uploadReceipt(widget.bill.id, _bytes!);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('تم ارسال الوصل بنجاح ✓', textAlign: TextAlign.right)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('فشل رفع الإيصال. حاول مجدداً.',
                  textAlign: TextAlign.right)),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) => ReceiptUploadView(
      bill: widget.bill,
      bytes: _bytes,
      uploading: _uploading,
      onPick: _pickImage,
      onUpload: _upload,
      onClose: () => Navigator.pop(context));
}

/// Pure receipt presentation shared by the live sheet and visual state tests.
/// Service calls, picked bytes and uploading state remain in the original State.
class ReceiptUploadView extends StatelessWidget {
  final Bill bill;
  final Uint8List? bytes;
  final bool uploading;
  final VoidCallback onPick, onUpload, onClose;
  const ReceiptUploadView(
      {super.key,
      required this.bill,
      required this.bytes,
      required this.uploading,
      required this.onPick,
      required this.onUpload,
      required this.onClose});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(PortalTokens.xl,
                PortalTokens.xl, PortalTokens.xl, PortalTokens.xl),
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Row(children: [
                    Expanded(
                        child: Text('ارسال وصل الدفع',
                            style: theme.textTheme.titleLarge)),
                    IconButton(
                        tooltip: 'إغلاق',
                        icon: const Icon(Icons.close),
                        onPressed: onClose)
                  ]),
                  PortalLabelValue(
                      label: 'فاتورة ${bill.month} ${bill.year}',
                      value: '₪${bill.amount}',
                      prominent: true),
                  const SizedBox(height: PortalTokens.xl),
                  Semantics(
                      button: true,
                      label: 'اختيار صورة الإيصال',
                      child: Material(
                          color: theme.scaffoldBackgroundColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  PortalTokens.radiusPanel),
                              side: BorderSide(
                                  color: bytes != null
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outline)),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                              onTap: uploading ? null : onPick,
                              child: SizedBox(
                                  height: PortalTokens.chartHeight,
                                  child: bytes != null
                                      ? Stack(fit: StackFit.expand, children: [
                                          Image.memory(bytes!,
                                              fit: BoxFit.cover),
                                          PositionedDirectional(
                                              top: PortalTokens.sm,
                                              end: PortalTokens.sm,
                                              child: Chip(
                                                  label: Text('تغيير الصورة',
                                                      style: theme.textTheme
                                                          .labelMedium),
                                                  avatar: const Icon(
                                                      Icons.edit_outlined))),
                                        ])
                                      : Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                              Icon(Icons.cloud_upload_outlined,
                                                  size: PortalTokens.target,
                                                  color: theme
                                                      .colorScheme.primary),
                                              const SizedBox(
                                                  height: PortalTokens.md),
                                              Text('اضغط لاختيار صورة الإيصال',
                                                  style: theme
                                                      .textTheme.bodyMedium),
                                              const SizedBox(
                                                  height: PortalTokens.xs),
                                              PortalNumber(
                                                  'PNG, JPG, JPEG مدعوم',
                                                  style: theme
                                                      .textTheme.bodySmall),
                                            ]))))),
                  const SizedBox(height: PortalTokens.xl),
                  ElevatedButton(
                      onPressed: (bytes == null || uploading) ? null : onUpload,
                      child: uploading
                          ? const SizedBox.square(
                              dimension: PortalTokens.icon,
                              child: CircularProgressIndicator())
                          : Text(bytes == null
                              ? 'اختر صورة أولاً'
                              : 'ارسال الوصل')),
                ]))));
  }
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
                ? 'تم رفض الوصل'
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
        note: isRejected ? 'اضغط لإعادة رفع وصل الدفع' : null,
        onTap: canUpload
            ? () => showPortalFormSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => _UploadReceiptSheet(uid: uid, bill: bill))
            : null);
  }
}

class _MockBills extends StatelessWidget {
  const _MockBills();

  static const _bills = [
    ('يوليو 2024', 284, 'pending'),
    ('يونيو 2024', 310, 'paid'),
    ('مايو 2024', 254, 'paid'),
    ('أبريل 2024', 296, 'paid'),
    ('مارس 2024', 210, 'paid'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _bills
          .map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(PortalTokens.lg),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius:
                        BorderRadius.circular(PortalTokens.radiusPanel),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(PortalTokens.md),
                        decoration: BoxDecoration(
                          color: (b.$3 == 'paid'
                                  ? PortalTone.success.colors(context).$1
                                  : PortalTone.warning.colors(context).$1)
                              .withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(PortalTokens.radius),
                        ),
                        child: Icon(
                          b.$3 == 'paid'
                              ? Icons.check_circle_outline
                              : Icons.pending_outlined,
                          size: 22,
                          color: b.$3 == 'paid'
                              ? PortalTone.success.colors(context).$1
                              : PortalTone.warning.colors(context).$1,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.$1,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            Text(b.$3 == 'paid' ? 'مدفوعة' : 'غير مدفوعة',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: b.$3 == 'paid'
                                            ? PortalTone.success
                                                .colors(context)
                                                .$1
                                            : PortalTone.warning
                                                .colors(context)
                                                .$1)),
                          ],
                        ),
                      ),
                      Text('₪${b.$2}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Icon(Icons.chevron_left,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 18),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}
