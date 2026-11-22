import '../../services/contact_fields.dart';
import '../finance/ledger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/tenant_store.dart';
import '../../models/user_model.dart';
import '../billing_settings/models.dart';
import '../metering/models.dart';

class RoundsRepository {
  final TenantStore store;
  RoundsRepository(this.store);
  FirebaseFirestore get db => store.db;
  Future<TenantActor> owner() async {
    final a = await store.requireOwner();
    if (a.superAdmin) throw StateError('لصاحب المولد فقط');
    return a;
  }

  DocumentReference<Map<String, dynamic>> doc(String c, String id) =>
      db.collection(c).doc(id);
  Future<String> addSubscriber(
      {required String name,
      required String phone,
      required String address,
      required String number,
      required int startingMilli,
      String userId = '',
      String readerUid = ''}) async {
    final a = await owner();
    if (name.trim().isEmpty ||
        name.length > 120 ||
        phone.length > 32 ||
        address.length > 240 ||
        number.isEmpty ||
        number.length > 80 ||
        startingMilli < 0 ||
        startingMilli > 1000000000) {
      throw const FormatException('بيانات المشترك غير صالحة');
    }
    final id =
        userId.isEmpty ? db.collection('billingSubscribers').doc().id : userId;
    if (userId.isNotEmpty) {
      final u = await store.checkedDocument('users', userId);
      if (UserProfile.fromMap(userId, u.data()!).role != UserRole.consumer) {
        throw StateError('الحساب ليس مشتركاً');
      }
    }
    await db.runTransaction((tx) async {
      final ref = doc('billingSubscribers', id);
      final old = await tx.get(ref);
      if (old.exists) throw StateError('المشترك مسجل مسبقاً');
      final link =
          userId.isEmpty ? null : await tx.get(doc('billingLinks', userId));
      if (link?.exists == true) throw StateError('الحساب مرتبط مسبقاً');
      tx.set(ref, {
        'generatorId': a.generatorId,
        'name': name.trim(),
        'phone': phone,
        'address': address,
        'number': number,
        'previousMilli': startingMilli,
        'averageMilli': 0,
        'recentDifferences': <int>[],
        'readerUid': readerUid.isEmpty ? a.uid : readerUid,
        'userId': userId,
        'active': true,
        'lastRoundId': '',
        'linkPending': false
      });
      if (userId.isNotEmpty) {
        tx.set(doc('billingLinks', userId),
            {'generatorId': a.generatorId, 'subscriberId': id});
      }
      tx.set(doc('accountBalances', id), {
        'generatorId': a.generatorId,
        'subscriberId': id,
        'userId': userId,
        'billedAgorot': 0,
        'collectedAgorot': 0
      });
    });
    return id;
  }

  Future<void> linkAccount(String sid, String uid) async {
    final a = await owner();
    final user = await store.checkedDocument('users', uid);
    if (UserProfile.fromMap(uid, user.data()!).role != UserRole.consumer) {
      throw StateError('حساب مشترك مطلوب');
    }
    final ref = doc('billingSubscribers', sid);
    await db.runTransaction((tx) async {
      final s = await tx.get(ref),
          link = await tx.get(doc('billingLinks', uid));
      if (s.data()?['generatorId'] != a.generatorId ||
          s.data()?['userId'] != '' ||
          link.exists) {
        throw StateError('الربط غير متاح');
      }
      tx.update(ref, {'userId': uid, 'linkPending': true});
      tx.update(doc('accountBalances', sid), {'userId': uid});
      tx.set(doc('billingLinks', uid),
          {'generatorId': a.generatorId, 'subscriberId': sid});
    });
    // Resumable projection: repeat this repair safely after interrupted linking.
    await repairLinks(sid);
  }

  Future<void> repairLinks(String sid) async {
    final a = await owner();
    final s = await doc('billingSubscribers', sid).get();
    if (s.data()?['generatorId'] != a.generatorId) {
      throw StateError('مشترك غير متاح');
    }
    final uid = s.data()!['userId'];
    if (uid == '') return;
    final bills = await db
        .collection('cycleBills')
        .where('generatorId', isEqualTo: a.generatorId)
        .where('subscriberId', isEqualTo: sid)
        .get();
    for (final b in bills.docs) {
      if (b.data()['userId'] != uid) await b.reference.update({'userId': uid});
    }
    final payments = await db
        .collection('cyclePayments')
        .where('generatorId', isEqualTo: a.generatorId)
        .where('subscriberId', isEqualTo: sid)
        .get();
    for (final p in payments.docs) {
      if (p.data()['userId'] != uid) await p.reference.update({'userId': uid});
    }
    await s.reference.update({'linkPending': false});
  }

  Future<void> editSubscriber(String sid,
      {required String name,
      required String phone,
      required String address,
      required String number}) async {
    final a = await owner();
    final record = await doc('billingSubscribers', sid).get();
    final issue = contactError(phone, '');
    if (record.data()?['generatorId'] != a.generatorId) {
      throw StateError('مشترك غير متاح');
    }
    if (issue != null ||
        name.trim().isEmpty ||
        name.length > 120 ||
        address.length > 240 ||
        number.trim().isEmpty ||
        number.length > 80) {
      throw FormatException(issue ?? 'تحقق من بيانات المشترك');
    }
    await record.reference.update({
      'name': name.trim(),
      'phone': normalizeMobile(phone),
      'address': address.trim(),
      'number': number.trim()
    });
  }

  Future<String> openRound(DateTime date) async {
    final a = await owner();
    final subs = await db
        .collection('billingSubscribers')
        .where('generatorId', isEqualTo: a.generatorId)
        .where('active', isEqualTo: true)
        .get();
    if (subs.docs.isEmpty || subs.size > 1000) {
      throw StateError('يلزم 1–1000 مشترك في الجولة');
    }
    final settingsDoc = await doc('billingSettings', a.generatorId).get();
    if (!settingsDoc.exists)
      throw StateError('احفظ إعدادات الفوترة قبل فتح جولة جديدة');
    final settings = BillingSettings.fromMap(settingsDoc.data()!);
    settings.validate();
    final rid = db.collection('billingRounds').doc().id;
    await db.runTransaction((tx) async {
      final active = await tx.get(doc('readerRounds', a.generatorId));
      if (active.exists &&
          !['closed', 'cancelled'].contains(active.data()?['status'])) {
        throw StateError('أكمل أو أغلق الجولة الحالية أولاً');
      }
      tx.set(doc('billingRounds', rid), {
        'generatorId': a.generatorId,
        'status': 'preparing',
        'date': date.millisecondsSinceEpoch,
        'cycleDays': settings.cycleDays,
        'settings': settings.toMap(),
        'subscriberIds': subs.docs.map((s) => s.id).toList(),
        'createdBy': a.uid
      });
      tx.set(doc('readerRounds', a.generatorId), {
        'generatorId': a.generatorId,
        'roundId': rid,
        'status': 'preparing',
        'date': date.millisecondsSinceEpoch,
        'cycleDays': settings.cycleDays
      });
    });
    await prepare(rid);
    return rid;
  }

  Future<void> prepare(String rid) async {
    final a = await owner();
    final r = await doc('billingRounds', rid).get();
    if (r.data()?['generatorId'] == a.generatorId &&
        r.data()?['status'] == 'open') return;
    if (r.data()?['generatorId'] != a.generatorId ||
        r.data()?['status'] != 'preparing') {
      throw StateError('جولة غير متاحة للتحضير');
    }
    for (final sid in List<String>.from(r.data()!['subscriberIds'])) {
      final s = (await doc('billingSubscribers', sid).get()).data()!;
      final ref = doc('meterAssignments', '${rid}_$sid');
      if ((await ref.get()).exists) continue;
      await ref.set(MeterAssignment(
              id: ref.id,
              generatorId: a.generatorId,
              readerUid: s['readerUid'],
              roundId: rid,
              name: s['name'],
              address: s['address'],
              number: s['number'],
              previousMilli: s['previousMilli'],
              averageMilli: s['averageMilli'])
          .toMap());
    }
    await db.runTransaction((tx) async {
      final fresh = await tx.get(r.reference),
          active = await tx.get(doc('readerRounds', a.generatorId));
      if (fresh.data()?['status'] == 'open') return;
      if (fresh.data()?['status'] != 'preparing' ||
          active.data()?['roundId'] != rid)
        throw StateError('تغيرت حالة الجولة؛ أعد فتح الشاشة');
      tx.update(r.reference, {'status': 'open'});
      tx.update(active.reference, {'status': 'open'});
    });
  }

  Future<void> cancelPreparation(String rid) async {
    final a = await owner();
    final bills = await db
        .collection('cycleBills')
        .where('generatorId', isEqualTo: a.generatorId)
        .where('roundId', isEqualTo: rid)
        .limit(1)
        .get();
    if (bills.docs.isNotEmpty)
      throw StateError('لا يمكن إلغاء جولة صدرت لها فواتير');
    await db.runTransaction((tx) async {
      final r = await tx.get(doc('billingRounds', rid)),
          active = await tx.get(doc('readerRounds', a.generatorId));
      if (r.data()?['generatorId'] != a.generatorId ||
          r.data()?['status'] != 'preparing' ||
          active.data()?['roundId'] != rid)
        throw StateError('الإلغاء متاح للجولة التي لا تزال قيد التحضير فقط');
      tx.update(r.reference, {'status': 'cancelled'});
      tx.update(active.reference, {'status': 'cancelled'});
    });
  }

  Future<void> assignReader(String sid, String uid) async {
    final a = await owner();
    final s = await doc('billingSubscribers', sid).get();
    if (s.data()?['generatorId'] != a.generatorId) {
      throw StateError('مشترك غير متاح');
    }
    if (uid != a.uid) {
      final staff = await doc('meterStaff', uid).get();
      if (staff.data()?['generatorId'] != a.generatorId ||
          staff.data()?['active'] != true) {
        throw StateError('عامل غير نشط');
      }
    }
    await s.reference.update({'readerUid': uid});
    final open = await doc('readerRounds', a.generatorId).get();
    if (open.data()?['status'] == 'open') {
      final ref = doc('meterAssignments', '${open.data()!['roundId']}_$sid');
      if ((await ref.get()).exists) await ref.update({'readerUid': uid});
    }
  }

  Future<void> ownerReading(String rid, String sid, int current,
      {bool newMeter = false,
      int? starting,
      String reason = '',
      bool confirmed = false}) async {
    final a = await owner();
    final row = await doc('meterAssignments', '${rid}_$sid').get();
    if (row.data()?['generatorId'] != a.generatorId) {
      throw StateError('قراءة غير متاحة');
    }
    final d = row.data()!;
    final r = await doc('billingRounds', rid).get();
    calculateBill(
        previousMilli: d['previousMilli'],
        currentMilli: current,
        settings: BillingSettings.fromMap(r.data()!['settings']),
        newMeter: newMeter,
        startingMilli: starting);
    if (newMeter && reason.trim().isEmpty) {
      throw StateError('سبب تغيير العداد مطلوب');
    }
    if (d['averageMilli'] > 0 &&
        current - d['previousMilli'] > d['averageMilli'] * 3 &&
        !confirmed) {
      throw StateError('أكد القفزة الكبيرة أولاً');
    }
    await doc('meterReadings', '${rid}_$sid').set({
      'generatorId': a.generatorId,
      'roundId': rid,
      'subscriberId': sid,
      'readerUid': d['readerUid'],
      'previousMilli': d['previousMilli'],
      'currentMilli': current,
      'confirmedJump': confirmed,
      'updatedBy': a.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      if (newMeter) ...{
        'newMeter': true,
        'startingMilli': starting,
        'reason': reason
      }
    });
  }

  Future<void> closeRound(String rid) async {
    final a = await owner();
    final r = await doc('billingRounds', rid).get();
    if (r.data()?['generatorId'] != a.generatorId) {
      throw StateError('جولة غير متاحة');
    }
    if (r.data()?['status'] == 'closed') return;
    final ids = List<String>.from(r.data()!['subscriberIds']);
    // Check all readings BEFORE freezing the round. Missing rows remain editable.
    for (final sid in ids) {
      if (!(await doc('meterReadings', '${rid}_$sid').get()).exists) {
        throw StateError('أكمل جميع القراءات قبل الإغلاق');
      }
    }
    final batch = db.batch();
    batch.update(r.reference, {'status': 'closing'});
    batch.update(doc('readerRounds', a.generatorId), {'status': 'closing'});
    await batch.commit();
    for (final sid in ids) {
      await _issue(a, rid, sid);
    }
    final end = db.batch();
    end.update(r.reference, {'status': 'closed'});
    end.update(doc('readerRounds', a.generatorId), {'status': 'closed'});
    await end.commit();
  }

  Future<void> _issue(TenantActor a, String rid, String sid) async {
    await db.runTransaction((tx) async {
      final bill = doc('cycleBills', '${rid}_$sid'), old = await tx.get(bill);
      if (old.exists) return;
      final round = await tx.get(doc('billingRounds', rid)),
          reading = await tx.get(doc('meterReadings', '${rid}_$sid')),
          subscriber = await tx.get(doc('billingSubscribers', sid)),
          balance = await tx.get(doc('accountBalances', sid));
      if (round.data()?['status'] != 'closing' ||
          subscriber.data()?['generatorId'] != a.generatorId ||
          !reading.exists) {
        throw StateError('جولة غير جاهزة');
      }
      final d = reading.data()!, s = subscriber.data()!, r = round.data()!;
      final ledger = await readLedger(tx, db, a.generatorId);
      final calc = calculateBill(
          previousMilli: d['previousMilli'],
          currentMilli: d['currentMilli'],
          settings: BillingSettings.fromMap(r['settings']),
          newMeter: d['newMeter'] == true,
          startingMilli: d['startingMilli']);
      await applyLedger(tx, db, ledger, [
        {
          'date': r['date'],
          'roundId': rid,
          'billedAgorot': calc.amountAgorot,
          'outstandingAgorot': calc.amountAgorot
        }
      ]);
      tx.set(bill, {
        'generatorId': a.generatorId,
        'roundId': rid,
        'subscriberId': sid,
        'userId': s['userId'],
        'name': s['name'],
        'date': r['date'],
        'snapshot': calc.toMap(),
        'amountAgorot': calc.amountAgorot,
        'paidAgorot': 0,
        'paymentSequence': 0,
        'pendingPaymentId': '',
        'published': false,
        'status': calc.amountAgorot == 0 ? 'paid' : 'unpaid',
        'revision': 0
      });
      tx.update(balance.reference, {
        'billedAgorot':
            (balance.data()?['billedAgorot'] ?? 0) + calc.amountAgorot
      });
      final recent = [
        ...List<int>.from(s['recentDifferences'] ?? []),
        calc.differenceMilli
      ];
      if (recent.length > 3) recent.removeAt(0);
      tx.update(subscriber.reference, {
        'previousMilli': calc.currentMilli,
        'lastRoundId': rid,
        'recentDifferences': recent,
        'averageMilli': recent.reduce((a, b) => a + b) ~/ recent.length
      });
    });
  }

  Future<void> correct(String billId, int current, String reason,
      {bool? newMeter, int? starting}) async {
    final a = await owner();
    if (reason.trim().isEmpty || reason.length > 500) {
      throw StateError('سبب التصحيح مطلوب');
    }
    final correction =
        doc('readingCorrections', db.collection('readingCorrections').doc().id);
    await db.runTransaction((tx) async {
      final ref = doc('cycleBills', billId), bill = await tx.get(ref);
      final b = bill.data();
      if (b == null ||
          b['generatorId'] != a.generatorId ||
          b['pendingPaymentId'] != '') {
        throw StateError('فاتورة غير متاحة للتصحيح');
      }
      final round = await tx.get(doc('billingRounds', b['roundId'])),
          active = await tx.get(doc('readerRounds', a.generatorId)),
          sub = await tx.get(doc('billingSubscribers', b['subscriberId'])),
          balance = await tx.get(doc('accountBalances', b['subscriberId']));
      if (round.data()?['status'] != 'closed' ||
          active.data()?['roundId'] != b['roundId'] ||
          !['closed', 'cancelled'].contains(active.data()?['status'])) {
        throw StateError(
            'التصحيح قبل فتح الجولة التالية فقط؛ لا نغيّر سلسلة قراءات لاحقة تلقائياً');
      }
      final ledger = await readLedger(tx, db, a.generatorId);
      final old = Map<String, dynamic>.from(b['snapshot']);
      final calc = calculateBill(
          previousMilli: old['previousMilli'],
          currentMilli: current,
          settings: BillingSettings.fromMap(old['settings']),
          newMeter: newMeter ?? old['newMeter'] == true,
          startingMilli: starting ?? old['startingMilli']);
      if (calc.amountAgorot < (b['paidAgorot'] as int)) {
        throw StateError(
            'اعكس الدفعة المعتمدة أولاً قبل خفض الفاتورة دون المدفوع');
      }
      await applyLedger(tx, db, ledger, [
        {
          'date': b['date'],
          'roundId': b['roundId'],
          'billedAgorot': calc.amountAgorot - b['amountAgorot'],
          'outstandingAgorot': calc.amountAgorot - b['amountAgorot']
        }
      ]);
      tx.update(ref, {
        'snapshot': calc.toMap(),
        'amountAgorot': calc.amountAgorot,
        'status': calc.amountAgorot == b['paidAgorot']
            ? 'paid'
            : b['paidAgorot'] > 0
                ? 'partial'
                : 'unpaid',
        'revision': b['revision'] + 1
      });
      tx.update(balance.reference, {
        'billedAgorot': balance.data()!['billedAgorot'] +
            calc.amountAgorot -
            b['amountAgorot']
      });
      tx.update(sub.reference, {'previousMilli': current});
      tx.set(correction, {
        'generatorId': a.generatorId,
        'billId': billId,
        'before': old,
        'after': calc.toMap(),
        'reason': reason.trim(),
        'by': a.uid,
        'at': FieldValue.serverTimestamp()
      });
    });
  }

  Future<void> submitPayment(String billId,
      {required int amount,
      required int date,
      required String reference,
      required String method,
      bool ownerEntry = false}) async {
    final a = ownerEntry ? await owner() : await store.actor();
    if (amount <= 0 ||
        reference.trim().isEmpty ||
        reference.length > 80 ||
        !['cash', 'bank', 'wallet', 'other'].contains(method) ||
        date < 946684800000 ||
        date > DateTime.now().millisecondsSinceEpoch + 86400000) {
      throw const FormatException('بيانات الدفع غير صالحة');
    }
    await db.runTransaction((tx) async {
      final bill = await tx.get(doc('cycleBills', billId));
      final b = bill.data();
      if (b == null ||
          b['generatorId'] != a.generatorId ||
          (!ownerEntry && b['userId'] != a.uid) ||
          (!ownerEntry && b['published'] != true) ||
          b['pendingPaymentId'] != '' ||
          amount > b['amountAgorot'] - b['paidAgorot']) {
        throw StateError('الدفعة غير متاحة أو توجد دفعة قيد المراجعة');
      }
      final seq = b['paymentSequence'] + 1, pid = '${billId}_$seq';
      tx.set(doc('cyclePayments', pid), {
        'generatorId': a.generatorId,
        'billId': billId,
        'subscriberId': b['subscriberId'],
        'userId': b['userId'],
        'roundId': b['roundId'],
        'amountAgorot': amount,
        'date': date,
        'reference': reference.trim(),
        'method': method,
        'status': 'pending',
        'sequence': seq,
        'submittedAt': FieldValue.serverTimestamp()
      });
      tx.update(
          bill.reference, {'paymentSequence': seq, 'pendingPaymentId': pid});
    });
  }

  Future<void> reviewPayment(String pid, bool approve,
      {String reason = ''}) async {
    final a = await owner();
    if (!approve && reason.trim().isEmpty) throw StateError('سبب الرفض مطلوب');
    await db.runTransaction((tx) async {
      final payment = await tx.get(doc('cyclePayments', pid));
      final p = payment.data();
      if (p == null || p['generatorId'] != a.generatorId) {
        throw StateError('دفعة غير متاحة');
      }
      if (p['status'] != 'pending') return;
      final bill = await tx.get(doc('cycleBills', p['billId'])),
          balance = await tx.get(doc('accountBalances', p['subscriberId']));
      final b = bill.data()!;
      final ledger = await readLedger(tx, db, a.generatorId);
      if (b['pendingPaymentId'] != pid) throw StateError('المراجعة قديمة');
      final paid = b['paidAgorot'] + (approve ? p['amountAgorot'] : 0);
      if (paid > b['amountAgorot']) throw StateError('الدفعة تتجاوز المستحق');
      if (approve) {
        await applyLedger(tx, db, ledger, [
          {
            'date': p['date'],
            'roundId': b['roundId'],
            'collectedAgorot': p['amountAgorot']
          },
          {
            'date': b['date'],
            'roundId': b['roundId'],
            'outstandingAgorot': -p['amountAgorot']
          }
        ]);
      }
      tx.update(payment.reference, {
        'status': approve ? 'approved' : 'rejected',
        'reason': reason.trim(),
        'reviewedBy': a.uid,
        'reviewedAt': FieldValue.serverTimestamp()
      });
      tx.update(bill.reference, {
        'paidAgorot': paid,
        'pendingPaymentId': '',
        'status': paid == b['amountAgorot']
            ? 'paid'
            : paid > 0
                ? 'partial'
                : 'unpaid'
      });
      if (approve) {
        tx.update(balance.reference, {
          'collectedAgorot':
              balance.data()!['collectedAgorot'] + p['amountAgorot']
        });
      }
    });
  }
}
