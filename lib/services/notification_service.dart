import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'tenant_store.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal()
      : _db = FirebaseFirestore.instance,
        _uid = (() => FirebaseAuth.instance.currentUser?.uid);
  NotificationService.forTesting(this._db, this._uid);
  final FirebaseFirestore _db;
  final String? Function() _uid;
  TenantStore get _store => TenantStore(_db, _uid);

  Future<void> addAlert(
      {required String userId,
      required String title,
      required String body,
      required String type}) async {
    final who = await _store.actor();
    final gid =
        who.superAdmin ? await _store.targetGenerator(userId) : who.generatorId;
    await _db.collection('alerts').add({
      'generatorId': gid,
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'read': false,
      'createdAt': DateTime.now().millisecondsSinceEpoch
    });
  }

  // Super-admin's real-time generator request list is the private request inbox.
  // Pending owners must never enumerate super-admin or other users' profiles.
  Future<void> notifySuperAdminNewOwner() async {}

  Future<void> _notifyOwner(String title, String body, String type) async {
    final who = await _store.actor();
    final generator =
        await _db.collection('generators').doc(who.generatorId).get();
    final uid = generator.data()?['ownerUid'] as String?;
    if (uid == null || uid.isEmpty) return;
    await addAlert(userId: uid, title: title, body: body, type: type);
  }

  Future<void> notifyAllAdminsNewConsumer() => _notifyOwner(
      'طلب انضمام جديد',
      'قام مستخدم جديد بتقديم طلب انضمام لمولدك، يرجى المراجعة.',
      'newConsumerRequest');
  Future<void> notifyAdminNewComplaint(String consumerName) => _notifyOwner(
      'شكوى جديدة 📢',
      'قام $consumerName بتقديم شكوى جديدة، يرجى المراجعة.',
      'complaint');
  Future<void> notifyUserApproved(String uid) => addAlert(
      userId: uid,
      title: 'تم قبول طلبك 🎉',
      body: 'تم تفعيل حسابك بنجاح.',
      type: 'requestApproved');
  Future<void> notifyUserRejected(String uid) => addAlert(
      userId: uid,
      title: 'تحديث بشأن طلبك',
      body: 'لم تتم الموافقة على طلب انضمامك.',
      type: 'requestRejected');
  Future<void> notifyPasswordReset(String uid) => addAlert(
      userId: uid,
      title: 'تم تغيير كلمة المرور',
      body: 'تم تعديل كلمة المرور الخاصة بحسابك.',
      type: 'passwordReset');

  Future<void> notifyAllUsersGeneratorState(bool isOn) async {
    final snap = await (await _store.query('users'))
        .where('role', whereIn: ['user', 'consumer'])
        .where('status', isEqualTo: 'approved')
        .get();
    for (final user in snap.docs) {
      await addAlert(
          userId: user.id,
          title: isOn ? 'تشغيل المولد ✅' : 'إيقاف المولد ⚠️',
          body: isOn
              ? 'تم تشغيل المولد. التيار الكهربائي متوفر الآن.'
              : 'تم إيقاف المولد مؤقتاً. التيار الكهربائي مقطوع حالياً.',
          type: isOn ? 'generatorOn' : 'generatorOff');
    }
  }
}
