import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:generator_portal/services/firebase_service.dart';
import 'package:generator_portal/features/billing_settings/models.dart';

void main() {
  test('invoice creation snapshots tariff and refuses stale manual amounts',
      () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('o').set(
        {'role': 'generator_owner', 'status': 'approved', 'generatorId': 'a'});
    await db
        .collection('users')
        .doc('c')
        .set({'role': 'user', 'status': 'approved', 'generatorId': 'a'});
    await db
        .collection('generators')
        .doc('a')
        .set({'status': 'approved', 'subscriptionStatus': 'active'});
    await db.collection('billingSettings').doc('a').set(
        const BillingSettings(priceAgorot: 2800, minimumUnitsMilli: 1500)
            .toMap());
    final service = FirebaseService.forTesting(db, () => 'o');
    await service.createBillWithConsumption(
        userId: 'c', amount: 280, kwh: 10, month: 'نوفمبر', year: 2026);
    final old = (await db.collection('bills').get()).docs.single;
    expect(old.data()['amountAgorot'], 28000);
    expect(old.data()['billingSnapshot']['settings']['priceAgorot'], 2800);
    await db
        .collection('billingSettings')
        .doc('a')
        .update({'priceAgorot': 3000});
    expect((await old.reference.get()).data(), old.data());
    await expectLater(
        service.createBillWithConsumption(
            userId: 'c', amount: 280, kwh: 10, month: 'نوفمبر', year: 2026),
        throwsStateError);
    expect((await db.collection('bills').get()).size, 1);
    await service.createBill(
        'c', 'ديسمبر', 2026, 45, 1); // minimum 1.5 units at 30
    expect(
        (await db.collection('bills').get())
            .docs
            .where((d) => d.data()['month'] == 'ديسمبر')
            .single
            .data()['amountAgorot'],
        4500);
  });
}
