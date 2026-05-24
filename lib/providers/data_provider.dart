import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bill_model.dart';
import '../models/alert_model.dart';
import '../models/complaint_model.dart';
import '../models/user_model.dart';

Stream<T> _safelyHandlePermissionDenied<T>(Stream<T> stream, T fallbackValue) {
  return stream.transform(StreamTransformer.fromHandlers(
    handleError: (error, stackTrace, sink) {
      if (error is FirebaseException && error.code == 'permission-denied') {
        sink.add(fallbackValue);
      } else {
        sink.addError(error, stackTrace);
      }
    },
  ));
}

// Generator status
class GeneratorState {
  final bool isOn;
  final DateTime? lastChanged;
  final int activeSubscribers;
  final double totalRevenue;
  final int complaints;

  const GeneratorState({
    this.isOn = false,
    this.lastChanged,
    this.activeSubscribers = 0,
    this.totalRevenue = 0,
    this.complaints = 0,
  });
}

final generatorProvider = StreamProvider<GeneratorState>((ref) {
  final db = FirebaseFirestore.instance;
  return db.collection('system').doc('generator').snapshots().map((s) {
    if (!s.exists) return const GeneratorState();
    final d = s.data()!;
    return GeneratorState(
      isOn: d['isOn'] ?? false,
      lastChanged: d['lastChanged'] != null
          ? DateTime.fromMillisecondsSinceEpoch(d['lastChanged'])
          : null,
    );
  });
});

// Bills
final billsProvider = StreamProvider.family<List<Bill>, String>((ref, userId) {
  final db = FirebaseFirestore.instance;
  return db
      .collection('bills')
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Bill.fromMap(d.id, d.data())).toList());
});

final allBillsProvider = StreamProvider<List<Bill>>((ref) {
  final db = FirebaseFirestore.instance;
  return _safelyHandlePermissionDenied(
    db
        .collection('bills')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Bill.fromMap(d.id, d.data())).toList()),
    const <Bill>[],
  );
});

// Alerts
final alertsProvider =
    StreamProvider.family<List<AppAlert>, String>((ref, userId) {
  final db = FirebaseFirestore.instance;
  return db
      .collection('alerts')
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => AppAlert.fromMap(d.id, d.data())).toList());
});

// Active subscribers (generator owner view)
// Single-field query + client-side filter to avoid composite-index requirement.
final subscribersProvider = StreamProvider<List<UserProfile>>((ref) {
  final db = FirebaseFirestore.instance;
  return db
      .collection('users')
      .where('role', whereIn: ['user', 'consumer'])
      .snapshots()
      .map((s) {
        final list = s.docs
            .map((d) => UserProfile.fromMap(d.id, d.data()))
            .where((u) => u.approvalStatus == ApprovalStatus.approved)
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
});

// Pending regular users (awaiting generator owner approval)
// Single-field query + client-side filter to avoid composite-index requirement.
final pendingUsersProvider = StreamProvider<List<UserProfile>>((ref) {
  final db = FirebaseFirestore.instance;
  return db
      .collection('users')
      .where('role', whereIn: ['user', 'consumer'])
      .snapshots()
      .map((s) {
        final list = s.docs
            .map((d) => UserProfile.fromMap(d.id, d.data()))
            .where((u) => u.approvalStatus == ApprovalStatus.pending)
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
});

// Pending generator owners (awaiting super admin approval)
// Single-field query + client-side filter to avoid composite-index requirement.
final pendingGeneratorOwnersProvider = StreamProvider<List<UserProfile>>((ref) {
  final db = FirebaseFirestore.instance;
  return _safelyHandlePermissionDenied<List<UserProfile>>(
    db
        .collection('users')
        .where('role', isEqualTo: 'generator_owner')
        .snapshots()
        .map((s) {
      final list = s.docs
          .map((d) => UserProfile.fromMap(d.id, d.data()))
          .where((u) => u.approvalStatus == ApprovalStatus.pending)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }),
    const <UserProfile>[],
  );
});

// Complaints
final complaintsProvider = StreamProvider<List<Complaint>>((ref) {
  final db = FirebaseFirestore.instance;
  return db
      .collection('complaints')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
          (s) => s.docs.map((d) => Complaint.fromMap(d.id, d.data())).toList());
});

// Highlighted bill id (used to deep-link from subscriber details → bills tab)
final highlightedBillProvider = StateProvider<String?>((ref) => null);

// uid → name lookup map for bills tab
final subscribersMapProvider = StreamProvider<Map<String, String>>((ref) {
  final db = FirebaseFirestore.instance;
  return _safelyHandlePermissionDenied(
    db
        .collection('users')
        .where('role', whereIn: ['user', 'consumer'])
        .snapshots()
        .map((s) =>
            {for (final d in s.docs) d.id: (d.data()['name'] ?? '') as String}),
    const <String, String>{},
  );
});

// Current month in Arabic
String currentMonthArabic() {
  const months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
  return months[DateTime.now().month - 1];
}

// Monthly bill stats for current month
class MonthlyBillStats {
  final int unpaidCount;
  final int unpaidAmount;
  final int paidCount;
  final int paidAmount;
  const MonthlyBillStats({
    this.unpaidCount = 0,
    this.unpaidAmount = 0,
    this.paidCount = 0,
    this.paidAmount = 0,
  });
}

final monthlyBillStatsProvider = Provider<MonthlyBillStats>((ref) {
  final billsAsync = ref.watch(allBillsProvider);
  return billsAsync.when(
    data: (bills) {
      final month = currentMonthArabic();
      final year = DateTime.now().year;
      final monthBills =
          bills.where((b) => b.month == month && b.year == year).toList();
      final unpaid = monthBills
          .where((b) =>
              b.status == BillStatus.pending ||
              b.status == BillStatus.pendingReview)
          .toList();
      final paid =
          monthBills.where((b) => b.status == BillStatus.paid).toList();
      return MonthlyBillStats(
        unpaidCount: unpaid.length,
        unpaidAmount: unpaid.fold(0, (s, b) => s + b.amount),
        paidCount: paid.length,
        paidAmount: paid.fold(0, (s, b) => s + b.amount),
      );
    },
    loading: () => const MonthlyBillStats(),
    error: (_, __) => const MonthlyBillStats(),
  );
});

// Usage data
class UsageMonth {
  final String month;
  final double kwh;
  final int cost;
  const UsageMonth(this.month, this.kwh, this.cost);
}

final usageProvider = Provider<List<UsageMonth>>((ref) => const [
      UsageMonth('يناير', 118, 236),
      UsageMonth('فبراير', 132, 264),
      UsageMonth('مارس', 105, 210),
      UsageMonth('أبريل', 148, 296),
      UsageMonth('مايو', 127, 254),
      UsageMonth('يونيو', 155, 310),
      UsageMonth('يوليو', 142, 284),
    ]);
