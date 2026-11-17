import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../../services/tenant_store.dart';
import 'models.dart';

class DistributionRepository {
  final TenantStore store;
  DistributionRepository(this.store);
  static const channel = MethodChannel('generator_portal/share');
  Future<TenantActor> owner() async {
    final a = await store.requireOwner();
    if (a.superAdmin) throw StateError('لصاحب المولد فقط');
    return a;
  }

  Future<PublishResult> publish(String rid) async {
    final a = await owner();
    final r = await store.db.collection('billingRounds').doc(rid).get();
    if (r.data()?['generatorId'] != a.generatorId ||
        r.data()?['status'] != 'closed') {
      throw StateError('أغلق الجولة أولاً');
    }
    final ids = List<String>.from(r.data()!['subscriberIds']);
    var sent = 0, skipped = 0, failed = 0, notified = 0;
    for (var i = 0; i < ids.length; i++) {
      final sid = ids[i];
      try {
        final result = await store.db.runTransaction((tx) async {
          final ref = store.db.collection('cycleBills').doc('${rid}_$sid'),
              snap = await tx.get(ref);
          final b = snap.data();
          if (b == null || b['generatorId'] != a.generatorId) {
            throw StateError('فاتورة غير متاحة');
          }
          if (b['published'] == true &&
              (b['publicationRecipient'] ?? '') == b['userId']) {
            return 0;
          }
          final uid = b['userId'] as String;
          tx.update(ref, {'published': true, 'publicationRecipient': uid});
          if (uid.isNotEmpty) {
            tx.set(store.db.collection('alerts').doc('cycle_${ref.id}'), {
              'generatorId': a.generatorId,
              'userId': uid,
              'title': 'فاتورة جولة جديدة',
              'body': 'تم إصدار فاتورة قراءة جديدة. راجع كشف حساب الجولات.',
              'type': 'newBill',
              'read': false,
              'createdAt': DateTime.now().millisecondsSinceEpoch
            });
          }
          return uid.isEmpty ? 1 : 2;
        });
        if (result == 0) {
          skipped++;
        } else {
          sent++;
          if (result == 2) notified++;
        }
      } catch (e) {
        failed++;
        if (e is FirebaseException &&
            ['unavailable', 'deadline-exceeded'].contains(e.code)) {
          failed += ids.length - i - 1;
          break;
        }
      }
    }
    return PublishResult(sent, skipped, failed, notified);
  }

  Future<void> share(String billId) async {
    final a = await owner();
    final d = await store.db.collection('cycleBills').doc(billId).get();
    if (d.data()?['generatorId'] != a.generatorId) {
      throw StateError('فاتورة غير متاحة');
    }
    await channel
        .invokeMethod<void>('shareText', {'text': billShareText(d.data()!)});
  }

  Future<void> markShared(String billId) async {
    final a = await owner();
    final d = await store.db.collection('cycleBills').doc(billId).get();
    if (d.data()?['generatorId'] != a.generatorId) {
      throw StateError('فاتورة غير متاحة');
    }
    await store.db.collection('billShares').doc(billId).set({
      'generatorId': a.generatorId,
      'billId': billId,
      'roundId':d.data()!['roundId'],
      'status': 'marked',
      'by': a.uid,
      'at': FieldValue.serverTimestamp()
    });
  }
}
