import 'package:flutter_test/flutter_test.dart';
import '../support/billing_fixture.dart';

void main() {
  test(
      'round close is resumable/idempotent, frozen invoice and partial payments exact',
      () async {
    final f = BillingFixture();
    await f.seed();
    final rid = await f.closed(), id = '${rid}_c';
    await f.owner.closeRound(rid);
    expect((await f.db.collection('cycleBills').get()).size, 1);
    final ref = f.db.collection('cycleBills').doc(id);
    expect((await ref.get()).data()!['amountAgorot'], 28000);
    await ref.update({'published': true});
    await f.consumer.submitPayment(id,
        amount: 10000, date: 1794700800000, reference: 'R1', method: 'cash');
    final pid = (await ref.get()).data()!['pendingPaymentId'];
    await f.owner.reviewPayment(pid, true);
    await f.owner.reviewPayment(pid, true);
    expect((await ref.get()).data()!['paidAgorot'], 10000);
    expect((await ref.get()).data()!['status'], 'partial');
    await expectLater(
        f.consumer.submitPayment(id,
            amount: 18001,
            date: 1794700800000,
            reference: 'over',
            method: 'cash'),
        throwsStateError);
    await f.consumer.submitPayment(id,
        amount: 18000, date: 1794700800000, reference: 'R2', method: 'bank');
    final p2 = (await ref.get()).data()!['pendingPaymentId'];
    await f.owner.reviewPayment(p2, false, reason: 'مرجع غير صحيح');
    expect((await ref.get()).data()!['paidAgorot'], 10000);
    await f.db
        .collection('billingSettings')
        .doc('g')
        .update({'priceAgorot': 4000});
    await f.owner.correct(id, 31000, 'تصحيح قراءة');
    expect((await ref.get()).data()!['amountAgorot'], 30800);
    expect((await f.db.collection('readingCorrections').get()).size, 1);
    expect(
        (await f.db.collection('accountBalances').doc('c').get())
            .data()!['billedAgorot'],
        30800);
  });
  test(
      'missing reading leaves round open; new meter explicit and minimum applied',
      () async {
    final f = BillingFixture();
    await f.seed();
    await f.owner.addSubscriber(
        name: 'يدوي', phone: '', address: '', number: '2', startingMilli: 5000);
    final subs = await f.db.collection('billingSubscribers').get();
    final sid = subs.docs.single.id;
    final rid = await f.owner.openRound(DateTime.utc(2026, 11, 15));
    await expectLater(f.owner.closeRound(rid), throwsStateError);
    expect(
        (await f.db.collection('billingRounds').doc(rid).get())
            .data()!['status'],
        'open');
    await expectLater(
        f.owner.ownerReading(rid, sid, 1000), throwsFormatException);
    await f.owner.ownerReading(rid, sid, 1000,
        newMeter: true, starting: 0, reason: 'استبدال');
    await f.owner.closeRound(rid);
    expect(
        (await f.db.collection('cycleBills').get())
            .docs
            .single
            .data()['amountAgorot'],
        4200);
  });
  test('manual subscriber account linking is unique and repairs prior invoices',
      () async {
    final f = BillingFixture();
    await f.seed();
    final sid = await f.owner.addSubscriber(
        name: 'يدوي', phone: '', address: '', number: '1', startingMilli: 0);
    final rid = await f.owner.openRound(DateTime.utc(2026, 11, 15));
    await f.owner.ownerReading(rid, sid, 1000);
    await f.owner.closeRound(rid);
    await f.owner.linkAccount(sid, 'c');
    expect(
        (await f.db.collection('cycleBills').doc('${rid}_$sid').get())
            .data()!['userId'],
        'c');
    await expectLater(
        f.owner.addSubscriber(
            name: 'مكرر',
            phone: '',
            address: '',
            number: '2',
            startingMilli: 0,
            userId: 'c'),
        throwsStateError);
  });
  test('linking manual subscriber preserves recorded payment history',
      () async {
    final f = BillingFixture();
    await f.seed();
    final sid = await f.owner.addSubscriber(
        name: 'يدوي', phone: '', address: '', number: '1', startingMilli: 0);
    final rid = await f.owner.openRound(DateTime.utc(2026, 11, 15));
    await f.owner.ownerReading(rid, sid, 1000);
    await f.owner.closeRound(rid);
    final id = '${rid}_$sid';
    await f.owner.submitPayment(id,
        amount: 1000,
        date: 1794700800000,
        reference: 'cash',
        method: 'cash',
        ownerEntry: true);
    final pid = (await f.db.collection('cycleBills').doc(id).get())
        .data()!['pendingPaymentId'];
    await f.owner.reviewPayment(pid, true);
    await f.owner.linkAccount(sid, 'c');
    expect(
        (await f.db.collection('cyclePayments').doc(pid).get())
            .data()!['userId'],
        'c');
    expect(
        (await f.db.collection('accountBalances').doc(sid).get())
            .data()!['collectedAgorot'],
        1000);
  });
}
