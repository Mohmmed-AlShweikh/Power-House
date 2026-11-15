import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:generator_portal/providers/auth_provider.dart';
import 'package:generator_portal/providers/data_provider.dart';
import 'support/multi_auth_fixture.dart';
import 'package:generator_portal/models/generator_model.dart';
import 'package:generator_portal/models/user_model.dart';
import 'package:generator_portal/models/bill_model.dart';
import 'package:generator_portal/services/tenant_store.dart';
import 'package:generator_portal/services/firebase_service.dart';
import 'package:generator_portal/services/notification_service.dart';
import 'package:generator_portal/providers/tenant_provider.dart';

void main() {
  late FakeFirebaseFirestore db;
  setUp(() async {
    db = FakeFirebaseFirestore();
    await db
        .collection('users')
        .doc('sa')
        .set({'role': 'super_admin', 'status': 'approved'});
  });
  Future<void> owner(String uid) async {
    await TenantStore(db, () => uid, nextGeneratorId: () => uid).enrollOwner(
        uid: uid,
        phone: '+970591234567',
        name: 'مولد $uid',
        sector: 'القطاع $uid');
  }

  Future<void> approve(String gid) => TenantStore(db, () => 'sa')
      .reviewGenerator(gid, GeneratorApproval.approved);
  Future<void> consumer(String uid, String gid) =>
      TenantStore(db, () => uid).enrollConsumer(
          uid: uid, phone: '+970591234568', name: uid, generatorId: gid);

  test('public generator IDs do not reveal the owner Auth UID', () async {
    await TenantStore(db, () => 'private-owner').enrollOwner(
        uid: 'private-owner',
        phone: '+970591234567',
        name: 'مولد',
        sector: 'الحي');
    final user =
        (await db.collection('users').doc('private-owner').get()).data()!;
    final gid = user['generatorId'] as String;
    expect(gid, isNot('private-owner'));
    await approve(gid);
    expect(
        (await db.collection('generatorDirectory').doc(gid).get()).data()!.keys,
        unorderedEquals(['name', 'sector', 'status', 'subscriptionStatus']));
  });
  test('auth membership clears explicitly on sign-out', () {
    final original = AuthState(
        user: PhoneUser('c'),
        profile: UserProfile(
            uid: 'c',
            name: 'أحمد',
            role: UserRole.consumer,
            createdAt: DateTime(2026)));
    final cleared = original.copyWith(user: null, profile: null);
    expect(cleared.user, isNull);
    expect(cleared.profile, isNull);
  });
  test(
      'owner enrollment atomically creates pending private records, not public directory',
      () async {
    await owner('a');
    final user = (await db.collection('users').doc('a').get()).data()!;
    expect(user['generatorId'], 'a');
    expect(user['status'], 'pending');
    expect(user['role'], 'generator_owner');
    expect(
        (await db.collection('generators').doc('a').get()).data()!['ownerUid'],
        'a');
    expect((await db.collection('generatorDirectory').get()).docs, isEmpty);
    await expectLater(owner('a'), throwsStateError);
  });

  test(
      'approval projection has exactly four public fields; suspension and subscription hide it',
      () async {
    await owner('a');
    await approve('a');
    var data =
        (await db.collection('generatorDirectory').doc('a').get()).data()!;
    expect(
        data.keys.toSet(), {'name', 'sector', 'status', 'subscriptionStatus'});
    expect(GeneratorAccount.fromMap('a', data).available, isTrue);
    final admin = TenantStore(db, () => 'sa');
    await admin.reviewGenerator('a', GeneratorApproval.suspended);
    data = (await db.collection('generatorDirectory').doc('a').get()).data()!;
    expect(GeneratorAccount.fromMap('a', data).available, isFalse);
    await admin.reviewGenerator('a', GeneratorApproval.approved,
        subscriptionStatus: 'inactive');
    await expectLater(consumer('c', 'a'), throwsStateError);
    await admin.reviewGenerator('a', GeneratorApproval.approved,
        subscriptionStatus: 'active');
    await consumer('c', 'a');
    expect((await db.collection('users').doc('c').get()).data()!['status'],
        'pending');
  });

  test('reject requires reason and publishes no owner personal data', () async {
    await owner('a');
    final admin = TenantStore(db, () => 'sa');
    await expectLater(admin.reviewGenerator('a', GeneratorApproval.rejected),
        throwsArgumentError);
    await admin.reviewGenerator('a', GeneratorApproval.rejected,
        reason: 'القطاع غير متاح');
    expect(
        (await db.collection('users').doc('a').get())
            .data()!['rejectionReason'],
        'القطاع غير متاح');
    final data =
        (await db.collection('generatorDirectory').doc('a').get()).data()!;
    expect(data.containsKey('phone'), isFalse);
    expect(data.containsKey('ownerUid'), isFalse);
  });

  test(
      'only the owning generator reviews consumers; caller cannot choose someone else uid',
      () async {
    await owner('a');
    await owner('b');
    await approve('a');
    await approve('b');
    await consumer('ca', 'a');
    await expectLater(TenantStore(db, () => 'b').reviewConsumer('ca', true),
        throwsStateError);
    await TenantStore(db, () => 'a').reviewConsumer('ca', true);
    expect(
        (await db.collection('users').doc('ca').get())
            .data()!['subscriptionStatus'],
        'active');
    await expectLater(TenantStore(db, () => 'ca').reviewConsumer('a', true),
        throwsStateError);
    await expectLater(
        TenantStore(db, () => 'a').enrollConsumer(
            uid: 'someone',
            phone: '+970591234568',
            name: 'x',
            generatorId: 'a'),
        throwsStateError);
  });

  test('bill+usage+alert and generator changes cannot escape actor tenant',
      () async {
    await owner('a');
    await owner('b');
    await approve('a');
    await approve('b');
    await consumer('ca', 'a');
    await consumer('cb', 'b');
    await TenantStore(db, () => 'a').reviewConsumer('ca', true);
    await TenantStore(db, () => 'b').reviewConsumer('cb', true);
    final service = FirebaseService.forTesting(db, () => 'a');
    await service.createBillWithConsumption(
        userId: 'ca', amount: 200, kwh: 100, month: 'نوفمبر', year: 2026);
    for (final collection in ['bills', 'consumption', 'alerts']) {
      final docs = (await db.collection(collection).get()).docs;
      expect(docs, hasLength(1));
      expect(docs.single.data()['generatorId'], 'a');
    }
    await expectLater(
        service.createBillWithConsumption(
            userId: 'cb', amount: 200, kwh: 100, month: 'نوفمبر', year: 2026),
        throwsStateError);
    await service.toggleGenerator(true);
    expect((await db.collection('generators').doc('a').get()).data()!['isOn'],
        true);
    expect((await db.collection('generators').doc('b').get()).data()!['isOn'],
        false);
    await db
        .collection('bills')
        .doc('foreign')
        .set({'generatorId': 'b', 'userId': 'cb', 'status': 'pending'});
    await expectLater(
        service.updateBillStatus('foreign', BillStatus.paid), throwsStateError);
  });

  test(
      'server-side tenant queries exclude other generators and constrain consumer uid',
      () async {
    for (final row in [
      ('aa', 'a', 'ca'),
      ('ab', 'a', 'other'),
      ('bb', 'b', 'cb')
    ]) {
      await db
          .collection('bills')
          .doc(row.$1)
          .set({'generatorId': row.$2, 'userId': row.$3});
    }
    expect(
        (await tenantQuery(db, 'bills', 'a').get())
            .docs
            .map((d) => d.id)
            .toSet(),
        {'aa', 'ab'});
    expect(
        (await tenantQuery(db, 'bills', 'a', userId: 'ca').get())
            .docs
            .single
            .id,
        'aa');
    expect((await tenantQuery(db, 'bills', 'a', superAdmin: true).get()).docs,
        hasLength(3));
  });

  test(
      'broadcast stays within tenant and role aliases; consumer complaint alerts only its owner',
      () async {
    await owner('a');
    await owner('b');
    await approve('a');
    await approve('b');
    await consumer('ca', 'a');
    await consumer('cb', 'b');
    await TenantStore(db, () => 'a').reviewConsumer('ca', true);
    await TenantStore(db, () => 'b').reviewConsumer('cb', true);
    await NotificationService.forTesting(db, () => 'a')
        .notifyAllUsersGeneratorState(true);
    final alerts = (await db.collection('alerts').get()).docs;
    expect(alerts, hasLength(1));
    expect(alerts.single.data()['userId'], 'ca');
    await NotificationService.forTesting(db, () => 'ca')
        .notifyAdminNewComplaint('ca');
    final ownerAlert = (await db
            .collection('alerts')
            .where('type', isEqualTo: 'complaint')
            .get())
        .docs
        .single;
    expect(ownerAlert.data()['userId'], 'a');
    expect(ownerAlert.data()['generatorId'], 'a');
  });

  test('phone-based billing lookup is restricted to the owning tenant',
      () async {
    await owner('a');
    await owner('b');
    await approve('a');
    await approve('b');
    await consumer('ca', 'a');
    await consumer('cb', 'b');
    final service = FirebaseService.forTesting(db, () => 'a');
    expect(await service.findUserByIdNumber('+970591234568'), 'ca');
  });

  test(
      'legacy owner subscription field does not override generator billing status',
      () async {
    await owner('a');
    await approve('a');
    await db
        .collection('users')
        .doc('a')
        .update({'subscriptionStatus': 'inactive'});
    expect((await TenantStore(db, () => 'a').requireOwner()).generatorId, 'a');
  });
  test('pending/suspended owners cannot review or issue invoices', () async {
    await owner('a');
    await expectLater(
        TenantStore(db, () => 'a').requireOwner(), throwsStateError);
    await approve('a');
    await TenantStore(db, () => 'sa')
        .reviewGenerator('a', GeneratorApproval.suspended);
    await expectLater(
        FirebaseService.forTesting(db, () => 'a').toggleGenerator(true),
        throwsStateError);
  });

  test(
      'activity and histories do not reuse previous tenant data while reloading',
      () async {
    final old = AsyncData<List<Bill>>([
      Bill(
          id: 'old',
          userId: 'a',
          month: 'نوفمبر',
          year: 2026,
          amount: 1,
          kwh: 1,
          status: BillStatus.pendingReview,
          createdAt: DateTime(2026))
    ]);
    final loading = const AsyncLoading<List<Bill>>().copyWithPrevious(old);
    expect(loading.valueOrNull,
        isNotEmpty); // Riverpod retains prior data by design.
    expect(settledValue(loading, <Bill>[]), isEmpty);
    final auth = MultiAuthFixture(AuthState(
        loading: false,
        startupResolved: true,
        user: PhoneUser('oa'),
        profile: UserProfile(
            uid: 'oa',
            name: 'مالك',
            role: UserRole.admin,
            generatorId: 'a',
            createdAt: DateTime(2026))));
    await db
        .collection('bills')
        .doc('a')
        .set({...old.value.single.toMap(), 'generatorId': 'a'});
    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(db),
      authProvider.overrideWith((ref) => auth)
    ]);
    final subscription = container.listen(recentActivitiesProvider, (_, __) {});
    addTearDown(() {
      subscription.close();
      container.dispose();
    });
    await container.read(allBillsProvider.future);
    expect(
        container
            .read(recentActivitiesProvider)
            .any((a) => a.action.contains('إيصال')),
        isTrue);
    auth.replace(AuthState(
        loading: false,
        startupResolved: true,
        user: PhoneUser('ob'),
        profile: UserProfile(
            uid: 'ob',
            name: 'مالك آخر',
            role: UserRole.admin,
            generatorId: 'b',
            createdAt: DateTime(2026))));
    expect(container.read(recentActivitiesProvider), isEmpty);
    await container.read(allBillsProvider.future);
    expect(container.read(recentActivitiesProvider), isEmpty);
  });

  test('legacy decoding and live default configuration fallback are explicit',
      () async {
    expect(
        UserProfile.fromMap('legacy', {'name': 'قديم', 'role': 'user'})
            .generatorId,
        defaultGeneratorId);
    expect(
        UserProfile.fromMap('sa', {'role': 'super_admin'}).generatorId, isNull);
    await db
        .collection('system')
        .doc('generator')
        .set({'isOn': true, 'pricePerKwh': 3});
    final stream = watchGenerator(db, defaultGeneratorId);
    final first = await stream.first;
    expect(first['pricePerKwh'], 3);
    expect(first['status'], 'approved');
    final migrated = watchGenerator(db, defaultGeneratorId)
        .firstWhere((d) => d['pricePerKwh'] == 4);
    await db.collection('generators').doc(defaultGeneratorId).set({
      'isOn': false,
      'pricePerKwh': 4,
      'status': 'approved',
      'subscriptionStatus': 'active'
    });
    expect((await migrated)['isOn'], false);
  });
}
