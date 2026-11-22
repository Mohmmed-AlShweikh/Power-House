import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generator_portal/features/distribution/repository.dart';
import 'package:generator_portal/services/tenant_store.dart';
import '../support/billing_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'publication resumes without duplicate alerts or resetting read state; share is explicit',
      () async {
    final f = BillingFixture();
    await f.seed();
    final rid = await f.closed(), id = '${rid}_c';
    final repo = DistributionRepository(TenantStore(f.db, () => 'o'));
    final first = await repo.publish(rid);
    expect(first.sent, 1);
    expect(first.notified, 1);
    expect((await f.db.collection('alerts').get()).size, 1);
    await f.db.collection('alerts').doc('cycle_$id').update({'read': true});
    final second = await repo.publish(rid);
    expect(second.skipped, 1);
    expect(
        (await f.db.collection('alerts').doc('cycle_$id').get())
            .data()!['read'],
        true);
    MethodCall? call;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DistributionRepository.channel, (c) async {
      call = c;
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DistributionRepository.channel, null));
    await repo.share(id);
    expect(call!.method, 'shareText');
    expect(call!.arguments['text'], contains('280.00'));
    expect((await f.db.collection('billShares').get()).size, 0);
    await repo.markShared(id);
    expect((await f.db.collection('billShares').get()).size, 1);
  });
  test(
      'manual invoice linked later gets one notification on resuming publication',
      () async {
    final f = BillingFixture();
    await f.seed();
    final sid = await f.owner.addSubscriber(
        name: 'يدوي', phone: '', address: '', number: '1', startingMilli: 0);
    final rid = await f.owner.openRound(DateTime.utc(2026, 11, 15));
    await f.owner.ownerReading(rid, sid, 1000);
    await f.owner.closeRound(rid);
    final repo = DistributionRepository(TenantStore(f.db, () => 'o'));
    expect((await repo.publish(rid)).notified, 0);
    await f.owner.linkAccount(sid, 'c');
    expect((await repo.publish(rid)).notified, 1);
    expect((await repo.publish(rid)).notified, 0);
  });
}
