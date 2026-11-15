import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/generator_model.dart';
import 'tenant_store.dart';
import '../config/app_config.dart';
import '../models/bill_model.dart';

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
      // Phone verification must use the native Android app ID/signing config.
      // google-services.json and AppConfig point to the same existing project.
      await Firebase.initializeApp();
      return;
    }
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: AppConfig.firebaseApiKey,
        authDomain: AppConfig.firebaseAuthDomain,
        projectId: AppConfig.firebaseProjectId,
        storageBucket: AppConfig.firebaseStorageBucket,
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

  // Add subscriber
  Future<void> addSubscriber(String uid, String name, String phone,
      String address, int ampereLimit) async {
    final who = await _store.requireOwner();
    final ref = _db.collection('users').doc(uid);
    await ref.set({
      'phone': phone,
      'name': name,
      'address': address,
      'role': 'user',
      'status': 'approved',
      'generatorId': who.generatorId,
      'subscriptionStatus': 'active',
      'ampereLimit': ampereLimit,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Add subscriber by phone (generates a document ID from phone number)
  Future<void> addSubscriberByPhone(
      String name, String phone, String address, int ampereLimit) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final who = await _store.requireOwner();
    final docId = 'sub_${who.generatorId}_$cleanPhone';
    await _db.collection('users').doc(docId).set({
      'phone': cleanPhone,
      'name': name,
      'address': address,
      'role': 'user',
      'status': 'approved',
      'generatorId': who.generatorId,
      'subscriptionStatus': 'active',
      'ampereLimit': ampereLimit,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Update subscriber
  Future<void> updateSubscriber(String uid,
      {String? name, String? address, String? status, int? ampereLimit}) async {
    await _store.requireOwner();
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (address != null) data['address'] = address;
    if (status != null) data['subscriptionStatus'] = status;
    if (ampereLimit != null) data['ampereLimit'] = ampereLimit;
    if (data.isNotEmpty) {
      await (await _store.checkedDocument('users', uid)).reference.update(data);
    }
  }

  // Approve/reject receipt
  Future<void> updateBillStatus(String billId, BillStatus status) async {
    await _store.requireOwner();
    await (await _store.checkedDocument('bills', billId)).reference.update({
      'status': status.name,
    });
  }

  // Upload receipt (Base64)
  Future<void> uploadReceipt(String billId, Uint8List imageBytes) async {
    final base64 = base64Encode(imageBytes);
    await (await _store.checkedDocument('bills', billId)).reference.update({
      'receiptBase64': base64,
      'status': 'pendingReview',
    });
  }

  // Upload receipt by userId (finds the latest pending bill)
  Future<void> uploadReceiptForUser(String userId, Uint8List imageBytes) async {
    final base64 = base64Encode(imageBytes);
    final query = await (await _store.query('bills', userId: userId))
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.update({
        'receiptBase64': base64,
        'status': 'pendingReview',
      });
    } else {
      throw StateError('لا توجد فاتورة معلقة لرفع الإيصال');
    }
  }

  // Decode Base64 to bytes
  static Uint8List decodeBase64(String base64) => base64Decode(base64);

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
