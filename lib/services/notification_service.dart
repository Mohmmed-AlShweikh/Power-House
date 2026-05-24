import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _messaging = FirebaseMessaging.instance;
  final _db = FirebaseFirestore.instance;

  Future<void> initialize() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    });
  }

  Future<String?> getAndSaveToken(String uid) async {
    try {
      String? token;
      if (AppConfig.fcmVapidKey.isNotEmpty) {
        token = await _messaging.getToken(vapidKey: AppConfig.fcmVapidKey);
      } else {
        token = await _messaging.getToken();
      }
      if (token != null && token.isNotEmpty) {
        await _db.collection('users').doc(uid).update({'fcm_token': token});
      }
      return token;
    } catch (_) {
      return null;
    }
  }

  Future<void> sendNotification({
    required String token,
    required String title,
    required String body,
  }) async {
    if (AppConfig.fcmServerKey.isEmpty) return;
    try {
      await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=${AppConfig.fcmServerKey}',
        },
        body: jsonEncode({
          'to': token,
          'notification': {'title': title, 'body': body},
          'android': {'priority': 'high'},
          'webpush': {
            'headers': {'Urgency': 'high'},
            'notification': {
              'title': title,
              'body': body,
              'icon': '/icons/Icon-192.png',
            },
          },
        }),
      );
    } catch (_) {}
  }

  Future<void> notifySuperAdminNewOwner() async {
    try {
      final snap = await _db
          .collection('users')
          .where('role', isEqualTo: 'super_admin')
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return;
      final token = snap.docs.first.data()['fcm_token'] as String?;
      if (token == null || token.isEmpty) return;
      await sendNotification(
        token: token,
        title: 'طلب تسجيل جديد',
        body: 'قام صاحب مولد جديد بتقديم طلب انضمام، يرجى المراجعة.',
      );
    } catch (_) {}
  }

  Future<void> notifyAllAdminsNewConsumer() async {
    try {
      final snap = await _db
          .collection('users')
          .where('role', isEqualTo: 'generator_owner')
          .where('status', isEqualTo: 'approved')
          .get();
      for (final doc in snap.docs) {
        final token = doc.data()['fcm_token'] as String?;
        if (token != null && token.isNotEmpty) {
          await sendNotification(
            token: token,
            title: 'طلب انضمام جديد',
            body: 'قام مستخدم جديد بتقديم طلب انضمام لمولدك، يرجى المراجعة.',
          );
        }
      }
    } catch (_) {}
  }

  Future<void> notifyUserApproved(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return;
      final token = doc.data()?['fcm_token'] as String?;
      if (token == null || token.isEmpty) return;
      await sendNotification(
        token: token,
        title: 'تم قبول طلبك 🎉',
        body: 'تهانينا! تم تفعيل حسابك بنجاح. يمكنك الآن تسجيل الدخول إلى التطبيق.',
      );
    } catch (_) {}
  }

  Future<void> notifyUserRejected(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return;
      final token = doc.data()?['fcm_token'] as String?;
      if (token == null || token.isEmpty) return;
      await sendNotification(
        token: token,
        title: 'تحديث بشأن طلبك',
        body: 'نعتذر منك، لم يتم الموافقة على طلب انضمامك للتطبيق.',
      );
    } catch (_) {}
  }
}
