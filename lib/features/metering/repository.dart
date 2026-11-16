import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/tenant_store.dart';
import '../billing_settings/models.dart';
import 'models.dart';

class MeteringRepository {
  final TenantStore store;
  MeteringRepository(this.store);
  Future<String> invite({int expiresAt = 0}) async {
    final a = await store.requireOwner();
    if (a.superAdmin) {
      throw StateError('لصاحب المولد فقط');
    }
    if (expiresAt != 0 && expiresAt <= DateTime.now().millisecondsSinceEpoch) {
      throw const FormatException('تاريخ انتهاء غير صالح');
    }
    final random = Random.secure();
    final code =
        List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
    await store.db.collection('meterInvites').doc(code).set({
      'generatorId': a.generatorId,
      'createdBy': a.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt,
      'revoked': false,
      'usedBy': ''
    });
    return code;
  }

  Future<void> revokeInvite(String code) async {
    final a = await store.requireOwner();
    final ref = store.db.collection('meterInvites').doc(code);
    final d = await ref.get();
    if (d.data()?['generatorId'] != a.generatorId) {
      throw StateError('دعوة غير متاحة');
    }
    await ref.update({'revoked': true});
  }

  Future<void> join(
      {required String uid,
      required String email,
      required String code,
      required String name}) async {
    if (store.currentUid() != uid ||
        name.trim().isEmpty ||
        name.length > 120 ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(code)) {
      throw const FormatException('تحقق من الاسم ورمز الدعوة');
    }
    final db = store.db;
    final inv = db.collection('meterInvites').doc(code),
        user = db.collection('users').doc(uid);
    await db.runTransaction((tx) async {
      final i = await tx.get(inv), u = await tx.get(user);
      final d = i.data();
      if (u.exists ||
          d == null ||
          d['revoked'] != false ||
          d['usedBy'] != '' ||
          (d['expiresAt'] != 0 &&
              d['expiresAt'] <= DateTime.now().millisecondsSinceEpoch)) {
        throw StateError('الدعوة غير متاحة أو انتهت صلاحيتها');
      }
      final gid = d['generatorId'];
      tx.set(user, {
        'name': name.trim(),
        'email': email,
        'phone': '',
        'idNumber': '',
        'address': '',
        'credentialVersion': 2,
        'role': 'meter_reader',
        'generatorId': gid,
        'status': 'approved',
        'subscriptionStatus': 'active',
        'ampereLimit': 0,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'inviteCode': code
      });
      tx.set(db.collection('meterStaff').doc(uid), {
        'name': name.trim(),
        'generatorId': gid,
        'active': true,
        'inviteCode': code
      });
      tx.update(inv, {'usedBy': uid});
    });
  }

  Future<void> revokeReader(String uid) async {
    final a = await store.requireOwner();
    final ref = store.db.collection('meterStaff').doc(uid);
    await store.db.runTransaction((tx) async {
      final d = await tx.get(ref);
      if (d.data()?['generatorId'] != a.generatorId) {
        throw StateError('العامل غير متاح');
      }
      tx.update(ref, {'active': false});
      tx.update(store.db.collection('users').doc(uid), {
        'status': 'suspended',
        'rejectionReason': 'تم إلغاء صلاحية قراءة العدادات'
      });
    });
  }

  /// A deterministic row id coalesces offline edits; metadata reports pending writes.
  Future<void> save(MeterAssignment row, int current,
      {bool confirmed = false}) async {
    if (current < row.previousMilli || current > 1000000000) {
      throw const FormatException(
          'القراءة الحالية أقل من السابقة أو خارج النطاق');
    }
    if (row.abnormal(current) && !confirmed) {
      throw StateError('قراءة مرتفعة؛ يلزم التأكيد');
    }
    final a = await store.actor();
    if (a.generatorId != row.generatorId) {
      throw StateError('مولد مختلف');
    }
    await store.db.collection('meterReadings').doc(row.id).set({
      'generatorId': row.generatorId,
      'roundId': row.roundId,
      'subscriberId': row.id.substring(row.roundId.length + 1),
      'readerUid': row.readerUid,
      'currentMilli': current,
      'previousMilli': row.previousMilli,
      'confirmedJump': confirmed,
      'updatedBy': a.uid,
      'updatedAt': FieldValue.serverTimestamp()
    });
  }

  Future<int> parseAndSave(MeterAssignment row, String input,
      {bool confirmed = false}) async {
    final n = parseFixed(input, 3);
    await save(row, n, confirmed: confirmed);
    return n;
  }
}
