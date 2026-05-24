import 'dart:async';

import 'package:flutter/material.dart';
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

// Bills — no orderBy to avoid composite index requirement; sort client-side
final billsProvider = StreamProvider.family<List<Bill>, String>((ref, userId) {
  if (userId.isEmpty) return Stream.value(const <Bill>[]);
  final db = FirebaseFirestore.instance;
  return db
      .collection('bills')
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((s) {
    final list =
        s.docs.map((d) => Bill.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  });
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
// Fetches ALL users and filters 100% client-side — zero Firestore query constraints.
final subscribersProvider = StreamProvider<List<UserProfile>>((ref) {
  final db = FirebaseFirestore.instance;
  return db.collection('users').snapshots().map((s) {
    final list = s.docs
        .map((d) => UserProfile.fromMap(d.id, d.data()))
        .where((u) =>
            u.role == UserRole.consumer &&
            u.approvalStatus == ApprovalStatus.approved)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  });
});

// Pending regular users (awaiting generator owner approval)
// Fetches ALL users and filters 100% client-side — zero Firestore query constraints.
final pendingUsersProvider = StreamProvider<List<UserProfile>>((ref) {
  final db = FirebaseFirestore.instance;
  return db.collection('users').snapshots().map((s) {
    final list = s.docs
        .map((d) => UserProfile.fromMap(d.id, d.data()))
        .where((u) =>
            u.role == UserRole.consumer &&
            u.approvalStatus == ApprovalStatus.pending)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  });
});

// Pending generator owners (awaiting super admin approval)
// Fetches ALL users and filters 100% client-side — zero Firestore query constraints.
final pendingGeneratorOwnersProvider = StreamProvider<List<UserProfile>>((ref) {
  final db = FirebaseFirestore.instance;
  return db.collection('users').snapshots().map((s) {
    final list = s.docs
        .map((d) => UserProfile.fromMap(d.id, d.data()))
        .where((u) =>
            u.role == UserRole.admin &&
            u.approvalStatus == ApprovalStatus.pending)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  });
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

// Consumption (per-user doc written by admin when issuing bill)
class ConsumptionData {
  final double monthlyUsage;
  final double dailyUsage;
  final String month;

  const ConsumptionData({
    this.monthlyUsage = 0,
    this.dailyUsage = 0,
    this.month = '',
  });
}

final consumptionProvider =
    StreamProvider.family<ConsumptionData, String>((ref, userId) {
  if (userId.isEmpty) return Stream.value(const ConsumptionData());
  final db = FirebaseFirestore.instance;
  return db.collection('consumption').doc(userId).snapshots().map((s) {
    if (!s.exists) return const ConsumptionData();
    final d = s.data()!;
    return ConsumptionData(
      monthlyUsage: (d['monthlyUsage'] ?? 0).toDouble(),
      dailyUsage: (d['dailyUsage'] ?? 0).toDouble(),
      month: d['month'] ?? '',
    );
  });
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

// ── Recent Activity Feed ──────────────────────────────────────────────────────

class ActivityItem {
  final String name;
  final String action;
  final DateTime createdAt;
  final Color color;
  const ActivityItem({
    required this.name,
    required this.action,
    required this.createdAt,
    required this.color,
  });
}

const Color _kActivityPrimary = Color(0xFF1E3A6E);
const Color _kActivitySuccess = Color(0xFF16A34A);
const Color _kActivityError = Color(0xFFDC2626);

final recentActivitiesProvider = Provider<List<ActivityItem>>((ref) {
  final bills = ref.watch(allBillsProvider).valueOrNull ?? [];
  final complaints = ref.watch(complaintsProvider).valueOrNull ?? [];
  final subscribers = ref.watch(subscribersProvider).valueOrNull ?? [];

  final subsMap = {for (final s in subscribers) s.uid: s.name};

  final activities = <ActivityItem>[];

  for (final bill in bills) {
    if (bill.status == BillStatus.pendingReview) {
      final name = subsMap[bill.userId] ?? 'مشترك';
      activities.add(ActivityItem(
        name: name,
        action: 'رفع إيصال ${bill.month}',
        createdAt: bill.createdAt,
        color: _kActivitySuccess,
      ));
    } else if (bill.status == BillStatus.paid) {
      final name = subsMap[bill.userId] ?? 'مشترك';
      activities.add(ActivityItem(
        name: name,
        action: 'تم دفع فاتورة ${bill.month}',
        createdAt: bill.createdAt,
        color: _kActivitySuccess,
      ));
    }
  }

  for (final complaint in complaints) {
    final preview = complaint.text.length > 22
        ? '${complaint.text.substring(0, 22)}...'
        : complaint.text;
    activities.add(ActivityItem(
      name: complaint.userName,
      action: 'شكوى: $preview',
      createdAt: complaint.createdAt,
      color: _kActivityError,
    ));
  }

  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
  for (final sub in subscribers) {
    if (sub.createdAt.isAfter(thirtyDaysAgo)) {
      activities.add(ActivityItem(
        name: sub.name,
        action: 'مشترك جديد',
        createdAt: sub.createdAt,
        color: _kActivityPrimary,
      ));
    }
  }

  activities.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return activities.take(10).toList();
});
