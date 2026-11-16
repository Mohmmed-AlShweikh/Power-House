import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/tenant_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/generator_model.dart';
import 'tenant_store.dart';
import '../config/app_config.dart';
import '../models/bill_model.dart';
import '../models/payment_model.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal()
      : _db = FirebaseFirestore.instance,
        _uid = (() => FirebaseAuth.instance.currentUser?.uid);
  FirebaseService.forTesting(this._db, this._uid);
  final FirebaseFirestore _db;
  final String? Function() _uid;
  TenantStore get _store => TenantStore(_db, _uid);

  Future<DocumentReference<Map<String, dynamic>>> _generatorRef() async {
    final who = await _store.requireOwner();
    final ref = _db.collection('generators').doc(who.generatorId);
    if (who.generatorId == defaultGeneratorId && !(await ref.get()).exists) {
      return _db.collection('system').doc('generator');
    }
    return ref;
  }

  static Future<void> initialize() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Authentication uses the native Android app ID/signing config.
      // google-services.json and AppConfig point to the same existing project.
      await Firebase.initializeApp();
      return;
    }
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: AppConfig.firebaseApiKey,
        authDomain: AppConfig.firebaseAuthDomain,
        projectId: AppConfig.firebaseProjectId,
        messagingSenderId: AppConfig.firebaseMessagingSenderId,
        appId: AppConfig.firebaseAppId,
      ),
    );
  }

  // Toggle generator and record the last ON/OFF timestamp
  Future<void> toggleGenerator(bool isOn) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final payload = {
      'isOn': isOn,
      'lastChanged': now,
      if (isOn) 'lastOnAt': now,
      if (!isOn) 'lastOffAt': now,
    };
    await (await _generatorRef()).set(payload, SetOptions(merge: true));
  }

  // Update current price per kWh for the system
  Future<void> updatePricePerKwh(double pricePerKwh) async {
    await (await _generatorRef()).set({
      'pricePerKwh': pricePerKwh,
    }, SetOptions(merge: true));
  }

  // Update the generator ON/OFF schedule times
  Future<void> updateGeneratorSchedule({
    required int scheduledOnMillis,
    required int scheduledOffMillis,
  }) async {
    await (await _generatorRef()).set({
      'scheduledOnAt': scheduledOnMillis,
      'scheduledOffAt': scheduledOffMillis,
    }, SetOptions(merge: true));
  }

  // Update subscriber
  Future<void> updateSubscriber(String uid,
      {String? name,
      String? address,
      String? status,
      int? ampereLimit,
      String? reason}) async {
    await _store.requireOwner();
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (address != null) data['address'] = address;
    if (status != null) {
      if (status == 'inactive' && (reason == null || reason.trim().isEmpty)) {
        throw ArgumentError('سبب الإيقاف مطلوب');
      }
      data['subscriptionStatus'] = status;
      data['status'] = status == 'inactive' ? 'suspended' : 'approved';
      data['rejectionReason'] = status == 'inactive' ? reason!.trim() : '';
    }
    if (ampereLimit != null) data['ampereLimit'] = ampereLimit;
    if (data.isNotEmpty) {
      await (await _store.checkedDocument('users', uid)).reference.update(data);
    }
  }

  // Single compact declaration per bill. Transactions fail offline instead of
  // queuing an unreviewed duplicate. No files, Storage or image bytes are written.
  Future<void> submitPayment(String billId, PaymentRecord payment) async {
    final who = await _store.actor();
    if (who.profile.role.name != 'consumer') throw StateError('للمشترك فقط');
    final now = DateTime.now().millisecondsSinceEpoch;
    if (payment.amountMinor <= 0 ||
        payment.date <= 0 ||
        payment.date > now + 86400000 ||
        payment.reference.trim().isEmpty ||
        payment.reference.trim().length > 80 ||
        !paymentMethods.containsKey(payment.method)) {
      throw ArgumentError('بيانات الدفع غير صحيحة');
    }
    final ref = _db.collection('bills').doc(billId);
    await _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      final data = doc.data();
      if (data == null ||
          data['userId'] != who.uid ||
          normalizedGeneratorId(data['generatorId']) != who.generatorId) {
        throw StateError('فاتورة غير متاحة');
      }
      if (payment.amountMinor != (data['amount'] as num).toInt() * 100) {
        throw ArgumentError('سجل المبلغ الكامل للفاتورة');
      }
      if (data['status'] == 'pendingReview') {
        final old = data['payment'] as Map?;
        if (old?['amountMinor'] == payment.amountMinor &&
            old?['date'] == payment.date &&
            old?['reference'] == payment.reference.trim() &&
            old?['method'] == payment.method) {
          return;
        }
        throw StateError('الدفع قيد المراجعة بالفعل');
      }
      if (!['pending', 'rejected'].contains(data['status'])) {
        throw StateError('لا يمكن إعادة دفع فاتورة معتمدة');
      }
      tx.update(ref, {
        'status': 'pendingReview',
        'payment': {
          ...payment.toMap(),
          'reference': payment.reference.trim(),
          'submittedAt': now,
          'version':
              ((data['payment'] as Map?)?['version'] as num? ?? 0).toInt() + 1
        }
      });
    });
  }

  Future<void> updateBillStatus(String billId, BillStatus status,
      {String reason = '', int? expectedVersion}) async {
    final who = await _store.requireOwner();
    if (![BillStatus.paid, BillStatus.rejected].contains(status)) {
      throw ArgumentError('قرار غير صحيح');
    }
    if (status == BillStatus.rejected &&
        (reason.trim().isEmpty || reason.length > 500)) {
      throw ArgumentError('سبب الرفض مطلوب');
    }
    final ref = _db.collection('bills').doc(billId);
    await _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      final data = doc.data();
      if (data == null ||
          (!who.superAdmin &&
              normalizedGeneratorId(data['generatorId']) != who.generatorId)) {
        throw StateError('فاتورة غير متاحة');
      }
      final version =
          ((data['payment'] as Map?)?['version'] as num?)?.toInt() ?? 0;
      if (expectedVersion != null && expectedVersion != version) {
        throw StateError('تغير سجل الدفع؛ أعد فتحه للمراجعة');
      }
      if (data['status'] == status.name) {
        return; // Idempotent repeated approval/rejection.
      }
      if (data['status'] != 'pendingReview' || data['payment'] is! Map) {
        throw StateError('لا توجد إفادة دفع بانتظار المراجعة');
      }
      tx.update(ref, {
        'status': status.name,
        'reviewReason': reason.trim(),
        'reviewedBy': who.uid,
        'reviewedVersion': version,
        'reviewedAt': DateTime.now().millisecondsSinceEpoch
      });
      final submitted = version;
      tx.set(
          _db
              .collection('alerts')
              .doc('review_${billId}_${submitted}_${status.name}'),
          {
            'generatorId': normalizedGeneratorId(data['generatorId']),
            'userId': data['userId'],
            'title': status == BillStatus.paid
                ? 'تم اعتماد الدفع'
                : 'تم رفض سجل الدفع',
            'body': status == BillStatus.paid
                ? 'تمت مراجعة الدفعة واعتمادها.'
                : reason.trim(),
            'type': status == BillStatus.paid
                ? 'paymentApproved'
                : 'paymentRejected',
            'read': false,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          });
    });
  }

  // Mark all alerts as read for a user
  Future<void> markAllAlertsRead(String userId) async {
    final batch = _db.batch();
    final snap = await (await _store.query('alerts', userId: userId))
        .where('read', isEqualTo: false)
        .get();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // Delete all alerts for a user
  Future<void> deleteAllAlerts(String userId) async {
    final batch = _db.batch();
    final snap = await (await _store.query('alerts', userId: userId)).get();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // File complaint
  Future<void> addComplaint(String userId, String userName, String text) async {
    await _db.collection('complaints').add({
      'generatorId': await _store.targetGenerator(userId),
      'userId': userId,
      'userName': userName,
      'text': text,
      'status': 'open',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Resolve complaint
  Future<void> resolveComplaint(String complaintId) async {
    await _store.requireOwner();
    await (await _store.checkedDocument('complaints', complaintId))
        .reference
        .update({
      'status': 'resolved',
    });
  }

  // Reply to complaint and mark as resolved
  Future<void> replyToComplaint(String complaintId, String replyText) async {
    await _store.requireOwner();
    await (await _store.checkedDocument('complaints', complaintId))
        .reference
        .update({
      'status': 'resolved',
      'reply': replyText,
      'replyAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Create bill (legacy — single document)
  Future<void> createBill(
      String userId, String month, int year, int amount, double kwh) async {
    await _store.requireOwner();
    await _db.collection('bills').add({
      'generatorId': await _store.targetGenerator(userId),
      'userId': userId,
      'month': month,
      'year': year,
      'amount': amount,
      'kwh': kwh,
      'status': 'pending',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Find a subscriber by their ID number (رقم الهوية)
  // Returns the UserProfile UID if found, null otherwise.
  Future<String?> findUserByIdNumber(String idNumber) async {
    final trimmed = idNumber.trim();
    if (trimmed.isEmpty) return null;
    final query = (await _store.query('users'))
        .where('role', whereIn: ['user', 'consumer']);
    for (final entry in [
      ('idNumber', trimmed),
      ('phone', trimmed),
      ('email', '$trimmed@powershare.app'),
    ]) {
      final snapshot =
          await query.where(entry.$1, isEqualTo: entry.$2).limit(1).get();
      if (snapshot.docs.isNotEmpty) return snapshot.docs.first.id;
    }
    return null;
  }

  // Resolve subscriber name from UID
  Future<String> getSubscriberName(String uid) async {
    final doc = await _store.checkedDocument('users', uid);
    if (!doc.exists) return '';
    return (doc.data()?['name'] ?? '') as String;
  }

  // Create bill + update consumption + send alert (atomic batch)
  Future<void> createBillWithConsumption({
    required String userId,
    required int amount,
    required double kwh,
    required String month,
    required int year,
    int? weekNumber,
  }) async {
    await _store.requireOwner();
    final batch = _db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. New bill document
    final billRef = _db.collection('bills').doc();
    batch.set(billRef, {
      'generatorId': await _store.targetGenerator(userId),
      'userId': userId,
      'month': month,
      'year': year,
      if (weekNumber != null) 'weekNumber': weekNumber,
      'amount': amount,
      'kwh': kwh,
      'status': 'pending',
      'createdAt': now,
      'billingPeriod': weekNumber != null ? 'weekly' : 'monthly',
    });

    // 2. Upsert consumption document (doc ID = userId)
    final consumptionRef = _db.collection('consumption').doc(userId);
    final dailyUsage = double.parse((kwh / 30).toStringAsFixed(2));
    final payload = {
      'generatorId': await _store.targetGenerator(userId),
      'userId': userId,
      'monthlyUsage': kwh,
      'dailyUsage': dailyUsage,
      'month': month,
      'updatedAt': now,
    };

    if (weekNumber != null) {
      payload['weeklyUsage'] = FieldValue.arrayUnion([
        {
          'generatorId': await _store.targetGenerator(userId),
          'month': month,
          'year': year,
          'weekNumber': weekNumber,
          'kwh': kwh,
          'amount': amount,
          'createdAt': now,
        }
      ]);
    }

    batch.set(consumptionRef, payload, SetOptions(merge: true));

    // 3. In-app alert belongs to the same tenant and atomic invoice batch.
    batch.set(_db.collection('alerts').doc(), {
      'generatorId': await _store.targetGenerator(userId),
      'userId': userId,
      'title': 'فاتورة مستحقة جديدة 🧾',
      'body': 'تم إصدار فاتورة جديدة لشهر $month، يرجى المراجعة والسداد.',
      'type': 'newBill',
      'read': false,
      'createdAt': now,
    });
    await batch.commit();
  }

  // Update user profile
  Future<void> updateUserProfile(
      String uid, String name, String address) async {
    await (await _store.checkedDocument('users', uid)).reference.update({
      'name': name,
      'address': address,
    });
  }

  // Approve a pending user or generator owner
  Future<void> approveUser(String uid) async {
    await _store.reviewConsumer(uid, true);
  }

  // Reject a pending user or generator owner
  Future<void> rejectUser(String uid,
      {String reason = 'لم تتم الموافقة على الطلب'}) async {
    await _store.reviewConsumer(uid, false, reason: reason);
  }
}

final firebaseServiceProvider = Provider<FirebaseService>((ref) =>
    FirebaseService.forTesting(
        ref.watch(firestoreProvider), () => ref.read(authProvider).user?.uid));
