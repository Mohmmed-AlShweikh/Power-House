import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/bill_model.dart';
import '../../../providers/data_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/firebase_service.dart';
import '../../../config/colors.dart';

class BillsTab extends ConsumerWidget {
  const BillsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).profile;
    final billsAsync = ref.watch(billsProvider(profile?.uid ?? ''));
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.primaryDark,
            automaticallyImplyLeading: false,
            title: Text('الفواتير',
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: Colors.white)),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _PendingBanner(),
                const SizedBox(height: 16),
                Text('سجل الفواتير', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                billsAsync.when(
                  data: (bills) => bills.isEmpty
                      ? const _EmptyBills()
                      : Column(
                          children: bills
                              .map((b) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _BillCard(bill: b),
                                  ))
                              .toList(),
                        ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const _MockBills(),
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

// ── Pending Banner ─────────────────────────────────────────────────────────────

class _PendingBanner extends ConsumerWidget {
  const _PendingBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primary]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child:
                const Icon(Icons.receipt_long, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('فاتورة يوليو غير مدفوعة',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 3),
                Text('المبلغ المستحق: ₪ 284',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final uid = ref.read(authProvider).profile?.uid ?? '';
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24))),
                builder: (_) => _UploadReceiptSheet(uid: uid),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
            child: const Text('رفع إيصال'),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2, end: 0, duration: 300.ms);
  }
}

// ── Upload Receipt Sheet ───────────────────────────────────────────────────────

class _UploadReceiptSheet extends ConsumerStatefulWidget {
  final String uid;
  const _UploadReceiptSheet({required this.uid});

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
      await FirebaseService().uploadReceiptForUser(widget.uid, _bytes!);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم رفع الإيصال بنجاح ✓',
                  textAlign: TextAlign.right)),
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
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('رفع إيصال الدفع',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text('فاتورة يوليو 2024 — ₪ 284',
                          style: Theme.of(context).textTheme.labelLarge),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _uploading ? null : _pickImage,
              child: AnimatedContainer(
                duration: 200.ms,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _bytes != null
                        ? AppColors.primary
                        : AppColors.lightBorder,
                    width: _bytes != null ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  color: Theme.of(context).scaffoldBackgroundColor,
                ),
                child: _bytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(_bytes!, fit: BoxFit.cover),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.edit,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_upload_outlined,
                                size: 40, color: AppColors.lightMuted),
                            SizedBox(height: 8),
                            Text('اضغط لاختيار صورة الإيصال',
                                style: TextStyle(
                                    color: AppColors.lightMuted,
                                    fontSize: 13)),
                            SizedBox(height: 4),
                            Text('PNG, JPG, JPEG مدعوم',
                                style: TextStyle(
                                    color: AppColors.lightMuted,
                                    fontSize: 11)),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: (_bytes == null || _uploading) ? null : _upload,
              child: _uploading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : Text(_bytes == null ? 'اختر صورة أولاً' : 'رفع الإيصال'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bill Card ─────────────────────────────────────────────────────────────────

class _EmptyBills extends StatelessWidget {
  const _EmptyBills();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long, size: 52, color: AppColors.lightMuted),
          SizedBox(height: 12),
          Text('لا توجد فواتير بعد',
              style: TextStyle(color: AppColors.lightMuted, fontSize: 15)),
        ],
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  final Bill bill;
  const _BillCard({required this.bill});

  @override
  Widget build(BuildContext context) {
    final isPaid = bill.status == BillStatus.paid;
    final isPendingReview = bill.status == BillStatus.pendingReview;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
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
              color: (isPaid
                      ? AppColors.success
                      : isPendingReview
                          ? AppColors.warning
                          : AppColors.error)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPaid
                  ? Icons.check_circle_outline
                  : isPendingReview
                      ? Icons.pending_outlined
                      : Icons.error_outline,
              size: 22,
              color: isPaid
                  ? AppColors.success
                  : isPendingReview
                      ? AppColors.warning
                      : AppColors.error,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${bill.month} ${bill.year}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lightText)),
                const SizedBox(height: 2),
                Text(
                  isPaid
                      ? 'مدفوعة'
                      : isPendingReview
                          ? 'بانتظار المراجعة'
                          : 'غير مدفوعة',
                  style: TextStyle(
                    fontSize: 12,
                    color: isPaid
                        ? AppColors.success
                        : isPendingReview
                            ? AppColors.warning
                            : AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text('₪${bill.amount}',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.lightText)),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_left,
              color: AppColors.lightMuted, size: 18),
        ],
      ),
    ).animate().fadeIn();
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(14),
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
                          color: (b.$3 == 'paid'
                                  ? AppColors.success
                                  : AppColors.warning)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          b.$3 == 'paid'
                              ? Icons.check_circle_outline
                              : Icons.pending_outlined,
                          size: 22,
                          color: b.$3 == 'paid'
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.$1,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            Text(
                                b.$3 == 'paid' ? 'مدفوعة' : 'غير مدفوعة',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: b.$3 == 'paid'
                                        ? AppColors.success
                                        : AppColors.warning)),
                          ],
                        ),
                      ),
                      Text('₪${b.$2}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const Icon(Icons.chevron_left,
                          color: AppColors.lightMuted, size: 18),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}
