import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:generator_portal/services/firebase_service.dart';
import 'package:generator_portal/models/payment_model.dart';
import 'package:generator_portal/models/bill_model.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirebaseService consumer, owner;
  setUp(() async {
    db = FakeFirebaseFirestore();
    for (final row in [
      ('c', 'user', 'a'),
      ('o', 'generator_owner', 'a'),
      ('other', 'generator_owner', 'b')
    ]) {
      await db.collection('users').doc(row.$1).set({
        'name': row.$1,
        'role': row.$2,
        'status': 'approved',
        'subscriptionStatus': 'active',
        'generatorId': row.$3
      });
    }
    for (final gid in ['a', 'b']) {
      await db
          .collection('generators')
          .doc(gid)
          .set({'status': 'approved', 'subscriptionStatus': 'active'});
    }
    await db.collection('bills').doc('bill').set({
      'generatorId': 'a',
      'userId': 'c',
      'amount': 100,
      'status': 'pending'
    });
    consumer = FirebaseService.forTesting(db, () => 'c');
    owner = FirebaseService.forTesting(db, () => 'o');
  });
  PaymentRecord payment([String reference = 'ref']) => PaymentRecord(
      amountMinor: 10000,
      date: DateTime.now().millisecondsSinceEpoch,
      reference: reference,
      method: 'cash');
  test('minor amounts parse exactly without floating-point rounding', () {
    expect(parsePaymentMinor('12.34'), 1234);
    expect(parsePaymentMinor('12.3'), 1230);
    expect(parsePaymentMinor('1.001'), isNull);
    expect(parsePaymentMinor('-1'), isNull);
  });
  test(
      'submitting payment stores compact fields only and same retry is idempotent',
      () async {
    final p = payment();
    await consumer.submitPayment('bill', p);
    final first = (await db.collection('bills').doc('bill').get()).data();
    await consumer.submitPayment('bill', p);
    expect((await db.collection('bills').doc('bill').get()).data(), first);
    expect((first!['payment'] as Map).keys.toSet(), {
      'amountMinor',
      'date',
      'reference',
      'method',
      'submittedAt',
      'version'
    });
    expect(first.containsKey('receiptBase64'), false);
  });
  test('approval repeats no mutation or notification and cannot be reversed',
      () async {
    await consumer.submitPayment('bill', payment());
    await owner.updateBillStatus('bill', BillStatus.paid, expectedVersion: 1);
    final first = (await db.collection('bills').doc('bill').get()).data();
    await owner.updateBillStatus('bill', BillStatus.paid, expectedVersion: 1);
    expect((await db.collection('bills').doc('bill').get()).data(), first);
    expect((await db.collection('alerts').get()).docs.length, 1);
    await expectLater(
        owner.updateBillStatus('bill', BillStatus.rejected, reason: 'late'),
        throwsStateError);
    await expectLater(
        consumer.submitPayment('bill', payment('new')), throwsStateError);
  });
  test(
      'rejection needs reason, resubmission increments version, stale dialog cannot approve',
      () async {
    await consumer.submitPayment('bill', payment());
    await expectLater(owner.updateBillStatus('bill', BillStatus.rejected),
        throwsArgumentError);
    await owner.updateBillStatus('bill', BillStatus.rejected,
        reason: 'رقم خاطئ', expectedVersion: 1);
    await consumer.submitPayment('bill', payment('corrected'));
    await expectLater(
        owner.updateBillStatus('bill', BillStatus.paid, expectedVersion: 1),
        throwsStateError);
    await owner.updateBillStatus('bill', BillStatus.paid, expectedVersion: 2);
    expect(
        (await db.collection('bills').doc('bill').get())
            .data()?['reviewedVersion'],
        2);
  });
  test('foreign owner and wrong payment amount cannot mutate bill', () async {
    await expectLater(
        consumer.submitPayment(
            'bill',
            PaymentRecord(
                amountMinor: 1,
                date: DateTime.now().millisecondsSinceEpoch,
                reference: 'x',
                method: 'cash')),
        throwsArgumentError);
    await consumer.submitPayment('bill', payment());
    await expectLater(
        FirebaseService.forTesting(db, () => 'other')
            .updateBillStatus('bill', BillStatus.paid),
        throwsStateError);
    expect((await db.collection('bills').doc('bill').get()).data()?['status'],
        'pendingReview');
  });
  test('cannot approve a bill with no payment declaration', () async {
    await expectLater(
        owner.updateBillStatus('bill', BillStatus.paid), throwsStateError);
  });
}
