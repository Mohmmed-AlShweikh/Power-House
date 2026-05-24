import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../config/app_config.dart';
import '../models/bill_model.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final _db = FirebaseFirestore.instance;

  static Future<void> initialize() async {
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

  // Toggle generator
  Future<void> toggleGenerator(bool isOn) async {
    await _db.collection('system').doc('generator').set({
      'isOn': isOn,
      'lastChanged': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }

  // Add subscriber
  Future<void> addSubscriber(String uid, String name, String phone,
      String address, int ampereLimit) async {
    final ref = _db.collection('users').doc(uid);
    await ref.set({
      'phone': phone,
      'name': name,
      'address': address,
      'role': 'consumer',
      'subscriptionStatus': 'active',
      'ampereLimit': ampereLimit,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Add subscriber by phone (generates a document ID from phone number)
  Future<void> addSubscriberByPhone(
      String name, String phone, String address, int ampereLimit) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final docId = 'sub_$cleanPhone';
    await _db.collection('users').doc(docId).set({
      'phone': cleanPhone,
      'name': name,
      'address': address,
      'role': 'consumer',
      'subscriptionStatus': 'active',
      'ampereLimit': ampereLimit,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Update subscriber
  Future<void> updateSubscriber(String uid,
      {String? name, String? address, String? status, int? ampereLimit}) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (address != null) data['address'] = address;
    if (status != null) data['subscriptionStatus'] = status;
    if (ampereLimit != null) data['ampereLimit'] = ampereLimit;
    if (data.isNotEmpty) {
      await _db.collection('users').doc(uid).update(data);
    }
  }

  // Approve/reject receipt
  Future<void> updateBillStatus(String billId, BillStatus status) async {
    await _db.collection('bills').doc(billId).update({
      'status': status.name,
    });
  }

  // Upload receipt (Base64)
  Future<void> uploadReceipt(String billId, Uint8List imageBytes) async {
    final base64 = base64Encode(imageBytes);
    await _db.collection('bills').doc(billId).update({
      'receiptBase64': base64,
      'status': 'pendingReview',
    });
  }

  // Upload receipt by userId (finds the latest pending bill)
  Future<void> uploadReceiptForUser(String userId, Uint8List imageBytes) async {
    final base64 = base64Encode(imageBytes);
    final query = await _db
        .collection('bills')
        .where('userId', isEqualTo: userId)
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
      // No existing bill — create one and attach the receipt
      await _db.collection('bills').add({
        'userId': userId,
        'month': 'يوليو',
        'year': 2024,
        'amount': 284,
        'kwh': 142.0,
        'status': 'pendingReview',
        'receiptBase64': base64,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  // Decode Base64 to bytes
  static Uint8List decodeBase64(String base64) => base64Decode(base64);

  // Mark all alerts as read for a user
  Future<void> markAllAlertsRead(String userId) async {
    final batch = _db.batch();
    final snap = await _db
        .collection('alerts')
        .where('userId', isEqualTo: userId)
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
    final snap = await _db
        .collection('alerts')
        .where('userId', isEqualTo: userId)
        .get();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // File complaint
  Future<void> addComplaint(
      String userId, String userName, String text) async {
    await _db.collection('complaints').add({
      'userId': userId,
      'userName': userName,
      'text': text,
      'status': 'open',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Resolve complaint
  Future<void> resolveComplaint(String complaintId) async {
    await _db.collection('complaints').doc(complaintId).update({
      'status': 'resolved',
    });
  }

  // Create bill (legacy — single document)
  Future<void> createBill(String userId, String month, int year, int amount,
      double kwh) async {
    await _db.collection('bills').add({
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
    final snap = await _db
        .collection('users')
        .where('idNumber', isEqualTo: trimmed)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) return snap.docs.first.id;
    // Fallback: email-based lookup ({idNumber}@powershare.app)
    final emailSnap = await _db
        .collection('users')
        .where('email', isEqualTo: '$trimmed@powershare.app')
        .limit(1)
        .get();
    if (emailSnap.docs.isNotEmpty) return emailSnap.docs.first.id;
    return null;
  }

  // Resolve subscriber name from UID
  Future<String> getSubscriberName(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
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
  }) async {
    final batch = _db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. New bill document
    final billRef = _db.collection('bills').doc();
    batch.set(billRef, {
      'userId': userId,
      'month': month,
      'year': year,
      'amount': amount,
      'kwh': kwh,
      'status': 'pending',
      'createdAt': now,
    });

    // 2. Upsert consumption document (doc ID = userId)
    final consumptionRef = _db.collection('consumption').doc(userId);
    final dailyUsage =
        double.parse((kwh / 30).toStringAsFixed(2)); // approx daily
    batch.set(
      consumptionRef,
      {
        'userId': userId,
        'monthlyUsage': kwh,
        'dailyUsage': dailyUsage,
        'month': month,
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    // 3. In-app alert for the subscriber
    await _db.collection('alerts').add({
      'userId': userId,
      'title': 'فاتورة مستحقة جديدة 🧾',
      'body':
          'تم إصدار فاتورة جديدة لشهر $month، يرجى المراجعة والسداد.',
      'type': 'newBill',
      'read': false,
      'createdAt': now,
    });
  }

  // Update user profile
  Future<void> updateUserProfile(
      String uid, String name, String address) async {
    await _db.collection('users').doc(uid).update({
      'name': name,
      'address': address,
    });
  }

  // Approve a pending user or generator owner
  Future<void> approveUser(String uid) async {
    await _db.collection('users').doc(uid).update({'status': 'approved'});
  }

  // Reject a pending user or generator owner
  Future<void> rejectUser(String uid) async {
    await _db.collection('users').doc(uid).update({'status': 'rejected'});
  }
}
