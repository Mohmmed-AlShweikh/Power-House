import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/generator_model.dart';
import '../models/user_model.dart';

Query<Map<String, dynamic>> tenantQuery(
    FirebaseFirestore db, String collection, String generatorId,
    {String? userId, bool superAdmin = false}) {
  Query<Map<String, dynamic>> query = db.collection(collection);
  if (!superAdmin) query = query.where('generatorId', isEqualTo: generatorId);
  if (userId != null) query = query.where('userId', isEqualTo: userId);
  return query;
}

class TenantActor {
  final String uid;
  final UserProfile profile;
  const TenantActor(this.uid, this.profile);
  String get generatorId => profile.generatorId ?? defaultGeneratorId;
  bool get superAdmin => profile.role == UserRole.superAdmin;
}

/// All client mutations derive membership from the authenticated user's record.
/// The optional uid seam is only for local fake/emulator tests.
class TenantStore {
  final FirebaseFirestore db;
  final String? Function() currentUid;
  TenantStore(this.db, this.currentUid);

  Future<TenantActor> actor() async {
    final uid = currentUid();
    if (uid == null || uid.isEmpty) throw StateError('يلزم تسجيل الدخول');
    final doc = await db.collection('users').doc(uid).get();
    if (!doc.exists) throw StateError('الحساب غير مكتمل');
    return TenantActor(uid, UserProfile.fromMap(uid, doc.data()!));
  }

  Future<TenantActor> requireOwner() async {
    final who = await actor();
    if (who.superAdmin) return who;
    if (who.profile.role != UserRole.admin ||
        who.profile.approvalStatus != ApprovalStatus.approved ||
        who.profile.subscriptionStatus != SubscriptionStatus.active) {
      throw StateError('الحساب غير مخوّل');
    }
    final generator =
        await db.collection('generators').doc(who.generatorId).get();
    if (generator.exists &&
        !GeneratorAccount.fromMap(generator.id, generator.data()!).available) {
      throw StateError('المولد غير متاح');
    }
    if (!generator.exists && who.generatorId != defaultGeneratorId) {
      throw StateError('المولد غير موجود');
    }
    return who;
  }

  void _validateEnrollment(String phone, String name, [String? sector]) {
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone) ||
        name.trim().isEmpty ||
        name.trim().length > 120 ||
        (sector != null &&
            (sector.trim().isEmpty || sector.trim().length > 120))) {
      throw ArgumentError('بيانات التسجيل غير صحيحة');
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> checkedDocument(
      String collection, String id) async {
    final who = await actor();
    final doc = await db.collection(collection).doc(id).get();
    if (!doc.exists) throw StateError('السجل غير موجود');
    if (!who.superAdmin &&
        normalizedGeneratorId(doc.data()?['generatorId']) != who.generatorId) {
      throw StateError('السجل يتبع مولداً آخر');
    }
    return doc;
  }

  Future<Query<Map<String, dynamic>>> query(String collection,
      {String? userId}) async {
    final who = await actor();
    return tenantQuery(db, collection, who.generatorId,
        userId: userId, superAdmin: who.superAdmin);
  }

  Future<String> targetGenerator(String uid) async {
    final doc = await checkedDocument('users', uid);
    return normalizedGeneratorId(doc.data()?['generatorId']);
  }

  Future<void> enrollOwner(
      {required String uid,
      required String phone,
      required String name,
      required String sector}) async {
    _validateEnrollment(phone, name, sector);
    if (currentUid() != uid) throw StateError('هوية غير مطابقة');
    final user = db.collection('users').doc(uid);
    if ((await user.get()).exists) throw StateError('الحساب مسجل مسبقاً');
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    batch.set(user, {
      'name': name.trim(),
      'phone': phone,
      'address': sector.trim(),
      'role': 'generator_owner',
      'status': 'pending',
      'subscriptionStatus': 'active',
      'generatorId': uid,
      'ampereLimit': 0,
      'createdAt': now
    });
    batch.set(db.collection('generators').doc(uid), {
      'name': name.trim(),
      'sector': sector.trim(),
      'ownerUid': uid,
      'status': 'pending',
      'subscriptionStatus': 'active',
      'rejectionReason': '',
      'createdAt': now,
      'isOn': false,
      'pricePerKwh': 2.0
    });
    await batch.commit();
  }

  Future<void> enrollConsumer(
      {required String uid,
      required String phone,
      required String name,
      required String generatorId}) async {
    _validateEnrollment(phone, name);
    if (generatorId.isEmpty || generatorId.contains('/')) {
      throw ArgumentError('مولد غير صحيح');
    }
    if (currentUid() != uid) throw StateError('هوية غير مطابقة');
    final user = db.collection('users').doc(uid);
    if ((await user.get()).exists) throw StateError('الحساب مسجل مسبقاً');
    final directory =
        await db.collection('generatorDirectory').doc(generatorId).get();
    if (!directory.exists ||
        !GeneratorAccount.fromMap(generatorId, directory.data()!).available) {
      throw StateError('هذا المولد غير متاح للتسجيل');
    }
    await user.set({
      'name': name.trim(),
      'phone': phone,
      'role': 'user',
      'generatorId': generatorId,
      'status': 'pending',
      'subscriptionStatus': 'inactive',
      'ampereLimit': 0,
      'createdAt': DateTime.now().millisecondsSinceEpoch
    });
  }

  Future<void> reviewGenerator(String gid, GeneratorApproval status,
      {String reason = '', String? subscriptionStatus}) async {
    final who = await actor();
    if (!who.superAdmin) throw StateError('للمشرف العام فقط');
    if (status == GeneratorApproval.rejected && reason.trim().isEmpty) {
      throw ArgumentError('سبب الرفض مطلوب');
    }
    final ref = db.collection('generators').doc(gid);
    final doc = await ref.get();
    if (!doc.exists) throw StateError('المولد غير موجود');
    final data = {
      ...doc.data()!,
      'status': status.name,
      'rejectionReason': reason.trim(),
      if (subscriptionStatus != null) 'subscriptionStatus': subscriptionStatus
    };
    final generator = GeneratorAccount.fromMap(gid, data);
    final batch = db.batch();
    batch.update(ref, {
      'status': status.name,
      'rejectionReason': reason.trim(),
      if (subscriptionStatus != null) 'subscriptionStatus': subscriptionStatus
    });
    if (generator.ownerUid.isNotEmpty) {
      batch.update(db.collection('users').doc(generator.ownerUid), {
        'status': status == GeneratorApproval.rejected
            ? 'rejected'
            : status == GeneratorApproval.pending
                ? 'pending'
                : 'approved',
        'rejectionReason': reason.trim(),
      });
    }
    batch.set(
        db.collection('generatorDirectory').doc(gid), generator.directory());
    await batch.commit();
  }

  Future<void> reviewConsumer(String uid, bool approve,
      {String reason = ''}) async {
    final who = await requireOwner();
    final doc = await checkedDocument('users', uid);
    final target = UserProfile.fromMap(uid, doc.data()!);
    if (!who.superAdmin &&
        (who.profile.role != UserRole.admin ||
            target.role != UserRole.consumer)) {
      throw StateError('لا تملك صلاحية مراجعة الحساب');
    }
    if (target.role == UserRole.admin && who.superAdmin) {
      final gen =
          await db.collection('generators').doc(target.generatorId).get();
      if (gen.exists) {
        await reviewGenerator(gen.id,
            approve ? GeneratorApproval.approved : GeneratorApproval.rejected,
            reason: approve
                ? ''
                : (reason.isEmpty ? 'لم تتم الموافقة على الطلب' : reason));
        return;
      }
    }
    await doc.reference.update({
      'status': approve ? 'approved' : 'rejected',
      'rejectionReason': reason,
      'subscriptionStatus': approve ? 'active' : 'inactive'
    });
  }
}
