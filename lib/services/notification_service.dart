import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _db = FirebaseFirestore.instance;

  Future<void> addAlert({
    required String userId,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      await _db.collection('alerts').add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'read': false,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
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
      final uid = snap.docs.first.id;
      await addAlert(
        userId: uid,
        title: 'طلب تسجيل جديد',
        body: 'قام صاحب مولد جديد بتقديم طلب انضمام، يرجى المراجعة.',
        type: 'newOwnerRequest',
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
        await addAlert(
          userId: doc.id,
          title: 'طلب انضمام جديد',
          body: 'قام مستخدم جديد بتقديم طلب انضمام لمولدك، يرجى المراجعة.',
          type: 'newConsumerRequest',
        );
      }
    } catch (_) {}
  }

  Future<void> notifyUserApproved(String uid) async {
    await addAlert(
      userId: uid,
      title: 'تم قبول طلبك 🎉',
      body: 'تهانينا! تم تفعيل حسابك بنجاح. يمكنك الآن تسجيل الدخول إلى التطبيق.',
      type: 'requestApproved',
    );
  }

  Future<void> notifyUserRejected(String uid) async {
    await addAlert(
      userId: uid,
      title: 'تحديث بشأن طلبك',
      body: 'نعتذر منك، لم يتم الموافقة على طلب انضمامك للتطبيق.',
      type: 'requestRejected',
    );
  }

  Future<void> notifyPasswordReset(String uid) async {
    await addAlert(
      userId: uid,
      title: 'تم تغيير كلمة المرور',
      body: 'تم تعديل كلمة المرور الخاصة بحسابك. إذا لم تكن أنت من قام بذلك، يرجى التواصل مع الدعم.',
      type: 'passwordReset',
    );
  }

  // Notify all users when generator state changes
  Future<void> notifyAllUsersGeneratorState(bool isOn) async {
    try {
      final snap = await _db
          .collection('users')
          .where('role', isEqualTo: 'consumer')
          .where('status', isEqualTo: 'approved')
          .get();
      for (final doc in snap.docs) {
        await addAlert(
          userId: doc.id,
          title: isOn ? 'تشغيل المولد ✅' : 'إيقاف المولد ⚠️',
          body: isOn
              ? 'تم تشغيل المولد. التيار الكهربائي متوفر الآن.'
              : 'تم إيقاف المولد مؤقتاً. التيار الكهربائي مقطوع حالياً.',
          type: isOn ? 'generatorOn' : 'generatorOff',
        );
      }
    } catch (_) {}
  }
}
