import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/tenant_store.dart';
import 'ledger.dart';
import 'models.dart';

class FinanceRepository {
  final TenantStore store;
  FinanceRepository(this.store);
  FirebaseFirestore get db => store.db;
  Future<TenantActor> owner() async {
    final a = await store.requireOwner();
    if (a.superAdmin) throw StateError('لصاحب المولد فقط');
    return a;
  }

  Future<void> expense(
      {String? id,
      required int amount,
      required int date,
      required String category,
      required String note,
      String roundId = 'manual',
      bool remove = false}) async {
    final a = await owner();
    if (amount <= 0 ||
        amount > 1000000000000 ||
        date < 946684800000 ||
        date > DateTime.now().millisecondsSinceEpoch + 86400000 ||
        !expenseCategories.containsKey(category) ||
        note.length > 500) {
      throw const FormatException('بيانات المصروف غير صالحة');
    }
    if (roundId != 'manual') {
      final r = await db.collection('billingRounds').doc(roundId).get();
      if (r.data()?['generatorId'] != a.generatorId) {
        throw StateError('جولة غير متاحة');
      }
    }
    final ref = db.collection('expenses').doc(id);
    await db.runTransaction((tx) async {
      final old = await tx.get(ref),
          context = await readLedger(tx, db, a.generatorId);
      if (old.exists && old.data()?['generatorId'] != a.generatorId) {
        throw StateError('مصروف غير متاح');
      }
      if (old.data()?['deleted'] == true) {
        throw StateError('المصروف محذوف مسبقاً');
      }
      final entries = <Map<String, dynamic>>[];
      if (old.exists) {
        final d = old.data()!;
        entries.add({
          'date': d['date'],
          'roundId': d['roundId'],
          'costAgorot': -d['amountAgorot'],
          '${d['category']}Agorot': -d['amountAgorot']
        });
      }
      if (!remove) {
        entries.add({
          'date': date,
          'roundId': roundId,
          'costAgorot': amount,
          '${category}Agorot': amount
        });
      }
      await applyLedger(tx, db, context, entries);
      tx.set(ref, {
        'generatorId': a.generatorId,
        'amountAgorot': amount,
        'date': date,
        'roundId': roundId,
        'category': category,
        'note': note,
        'deleted': remove,
        'createdBy': old.data()?['createdBy'] ?? a.uid,
        'createdAt': old.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
        'updatedBy': a.uid,
        'updatedAt': FieldValue.serverTimestamp()
      });
      final event = db.collection('expenseChanges').doc();
      tx.set(event, {
        'generatorId': a.generatorId,
        'expenseId': ref.id,
        'before': old.data(),
        'after': {
          'amountAgorot': amount,
          'date': date,
          'category': category,
          'note': note,
          'deleted': remove
        },
        'by': a.uid,
        'at': FieldValue.serverTimestamp()
      });
    });
  }

  Future<void> reversePayment(String pid, String reason) async {
    final a = await owner();
    if (reason.trim().isEmpty || reason.length > 500) {
      throw StateError('سبب العكس مطلوب');
    }
    await db.runTransaction((tx) async {
      final p = await tx.get(db.collection('cyclePayments').doc(pid));
      if (p.data()?['generatorId'] != a.generatorId) {
        throw StateError('دفعة غير متاحة');
      }
      if (p.data()?['status'] == 'reversed') return;
      if (p.data()?['status'] != 'approved') {
        throw StateError('الدفعة غير معتمدة');
      }
      final data = p.data()!;
      final bill =
              await tx.get(db.collection('cycleBills').doc(data['billId'])),
          balance = await tx
              .get(db.collection('accountBalances').doc(data['subscriberId'])),
          ctx = await readLedger(tx, db, a.generatorId);
      final b = bill.data()!;
      if (b['pendingPaymentId'] != '') {
        throw StateError('راجع الدفعة المعلقة أولاً');
      }
      final paid = b['paidAgorot'] - data['amountAgorot'];
      if (paid < 0) {
        throw StateError('رصيد غير متسق؛ أعد حساب الملخصات وراجع السجل');
      }
      await applyLedger(tx, db, ctx, [
        {
          'date': data['date'],
          'roundId': b['roundId'],
          'collectedAgorot': -data['amountAgorot']
        },
        {
          'date': b['date'],
          'roundId': b['roundId'],
          'outstandingAgorot': data['amountAgorot']
        }
      ]);
      tx.update(p.reference, {
        'status': 'reversed',
        'reversalReason': reason.trim(),
        'reversedBy': a.uid,
        'reversedAt': FieldValue.serverTimestamp()
      });
      tx.update(bill.reference,
          {'paidAgorot': paid, 'status': paid == 0 ? 'unpaid' : 'partial'});
      tx.update(balance.reference, {
        'collectedAgorot':
            balance.data()!['collectedAgorot'] - data['amountAgorot']
      });
    });
  }

  /// Rare owner repair: lock financial mutations, build a new generation, swap.
  /// Prior generations remain retained; no data or history is deleted.
  Future<void> rebuild() async {
    final a = await owner(), token = db.collection('financeSummaries').doc().id;
    final control = db.collection('financeControl').doc(a.generatorId);
    await db.runTransaction((tx) async {
      final c = await tx.get(control);
      if (c.data()?['locked'] == true &&
          DateTime.now().millisecondsSinceEpoch -
                  (c.data()?['startedAt'] as int? ?? 0) <
              600000) {
        throw StateError(
            'إعادة الحساب جارية؛ أعد المحاولة بعد 10 دقائق إذا انقطع الجهاز');
      }
      tx.set(control, {
        'generatorId': a.generatorId,
        'generation': c.data()?['generation'] ?? 'initial',
        'locked': true,
        'token': token,
        'startedAt': DateTime.now().millisecondsSinceEpoch
      });
    });
    try {
      final entries = <Map<String, dynamic>>[];
      for (final d in (await db
              .collection('cycleBills')
              .where('generatorId', isEqualTo: a.generatorId)
              .get())
          .docs) {
        final b = d.data();
        entries.add({
          'date': b['date'],
          'roundId': b['roundId'],
          'billedAgorot': b['amountAgorot'],
          'outstandingAgorot': b['amountAgorot'] - b['paidAgorot']
        });
      }
      for (final d in (await db
              .collection('cyclePayments')
              .where('generatorId', isEqualTo: a.generatorId)
              .where('status', isEqualTo: 'approved')
              .get())
          .docs) {
        final p = d.data();
        entries.add({
          'date': p['date'],
          'roundId': p['roundId'],
          'collectedAgorot': p['amountAgorot']
        });
      }
      for (final d in (await db
              .collection('expenses')
              .where('generatorId', isEqualTo: a.generatorId)
              .where('deleted', isEqualTo: false)
              .get())
          .docs) {
        final e = d.data();
        entries.add({
          'date': e['date'],
          'roundId': e['roundId'],
          'costAgorot': e['amountAgorot'],
          '${e['category']}Agorot': e['amountAgorot']
        });
      }
      for (final d in (await db
              .collection('bills')
              .where('generatorId', isEqualTo: a.generatorId)
              .get())
          .docs) {
        final b = d.data(), money = (b['amount'] as int) * 100;
        entries.add({
          'date': b['createdAt'] ?? 0,
          'roundId': 'manual',
          'billedAgorot': money,
          'outstandingAgorot': b['status'] == 'paid' ? 0 : money
        });
        if (b['status'] == 'paid') {
          entries.add({
            'date': b['payment']?['date'] ?? b['createdAt'] ?? 0,
            'roundId': 'manual',
            'collectedAgorot': money
          });
        }
      }
      final values = ledgerDeltas(a.generatorId, token, entries);
      if (values.isEmpty) {
        values.addAll(ledgerDeltas(a.generatorId, token, [
          {'date': DateTime.now().millisecondsSinceEpoch, 'roundId': 'manual'}
        ]));
      }
      for (final e in values.entries) {
        await db.collection('financeSummaries').doc(e.key).set(e.value);
      }
      await db.runTransaction((tx) async {
        final c = await tx.get(control);
        if (c.data()?['token'] != token) {
          throw StateError('تغيرت عملية إعادة الحساب');
        }
        tx.update(control, {'generation': token, 'locked': false});
      });
    } catch (_) {
      await db.runTransaction((tx) async {
        final c = await tx.get(control);
        if (c.data()?['token'] == token) tx.update(control, {'locked': false});
      });
      rethrow;
    }
  }
}
