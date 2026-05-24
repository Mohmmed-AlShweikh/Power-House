import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bill_model.dart';
import '../models/alert_model.dart';
import '../models/complaint_model.dart';
import '../models/user_model.dart';

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
  return db
      .collection('bills')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Bill.fromMap(d.id, d.data())).toList());
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
      .map(
          (s) => s.docs.map((d) => AppAlert.fromMap(d.id, d.data())).toList());
});

// Active subscribers (generator owner view)
final subscribersProvider = StreamProvider<List<UserProfile>>((ref) {
  final db = FirebaseFirestore.instance;
  return db
      .collection('users')
      .where('role', whereIn: ['user', 'consumer'])
      .where('status', isEqualTo: 'approved')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
          (s) => s.docs.map((d) => UserProfile.fromMap(d.id, d.data())).toList());
});

// Pending regular users (awaiting generator owner approval)
final pendingUsersProvider = StreamProvider<List<UserProfile>>((ref) {
  final db = FirebaseFirestore.instance;
  return db
      .collection('users')
      .where('role', whereIn: ['user', 'consumer'])
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
          (s) => s.docs.map((d) => UserProfile.fromMap(d.id, d.data())).toList());
});

// Pending generator owners (awaiting super admin approval)
final pendingGeneratorOwnersProvider =
    StreamProvider<List<UserProfile>>((ref) {
  final db = FirebaseFirestore.instance;
  return db
      .collection('users')
      .where('role', whereIn: ['generator_owner', 'admin'])
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
          (s) => s.docs.map((d) => UserProfile.fromMap(d.id, d.data())).toList());
});

// Complaints
final complaintsProvider = StreamProvider<List<Complaint>>((ref) {
  final db = FirebaseFirestore.instance;
  return db
      .collection('complaints')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => Complaint.fromMap(d.id, d.data())).toList());
});

// Highlighted bill id (used to deep-link from subscriber details → bills tab)
final highlightedBillProvider = StateProvider<String?>((ref) => null);

// uid → name lookup map for bills tab
final subscribersMapProvider = StreamProvider<Map<String, String>>((ref) {
  final db = FirebaseFirestore.instance;
  return db
      .collection('users')
      .where('role', whereIn: ['user', 'consumer'])
      .snapshots()
      .map((s) => {for (final d in s.docs) d.id: (d.data()['name'] ?? '') as String});
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
