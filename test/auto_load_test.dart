import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generator_portal/services/firestore_reads.dart';
import 'package:generator_portal/providers/auth_provider.dart';
import 'package:generator_portal/providers/tenant_provider.dart';
import 'package:generator_portal/providers/data_provider.dart';
import 'package:generator_portal/models/user_model.dart';
import 'support/multi_auth_fixture.dart';

void main() {
  test('permission-denied and unavailable retry twice then load automatically',
      () async {
    var calls = 0;
    final stream = retryFirestore(() {
      calls++;
      return calls < 3
          ? Stream<int>.error(FirebaseException(
              plugin: 'cloud_firestore',
              code: calls == 1 ? 'permission-denied' : 'unavailable'))
          : Stream.value(42);
    }, backoff: const [Duration(milliseconds: 1), Duration(milliseconds: 1)]);
    expect(await stream.first, 42);
    expect(calls, 3);
  });
  test(
      'permanent denial exposes error only after two retries; other errors never retry',
      () async {
    for (final code in ['permission-denied', 'failed-precondition']) {
      var calls = 0;
      final stream = retryFirestore<int>(() {
        calls++;
        return Stream.error(
            FirebaseException(plugin: 'cloud_firestore', code: code));
      }, backoff: const [Duration(milliseconds: 1), Duration(milliseconds: 1)]);
      await expectLater(stream.first, throwsA(isA<FirebaseException>()));
      expect(calls, code == 'permission-denied' ? 3 : 1);
    }
  });
  test('cancel during backoff never opens another listener', () async {
    var calls = 0;
    final stream = retryFirestore<int>(() {
      calls++;
      return Stream.error(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));
    }, backoff: const [Duration(milliseconds: 30)]);
    final sub = stream.listen((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await sub.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(calls, 1);
  });
  test(
      'picker waits for authentication and reloads automatically for a new UID without profile',
      () async {
    final db = FakeFirebaseFirestore(), auth = MultiAuthFixture();
    await db.collection('generatorDirectory').doc('g').set({
      'name': 'مولد',
      'sector': 'غزة',
      'status': 'approved',
      'subscriptionStatus': 'active'
    });
    for (final gid in ['a', 'b']) {
      await db
          .collection('generators')
          .doc(gid)
          .set({'status': 'approved', 'subscriptionStatus': 'active'});
    }
    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(db),
      authProvider.overrideWith((ref) => auth)
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(generatorDirectoryProvider, (_, __) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(generatorDirectoryProvider).isLoading, true);
    auth.replace(AuthState(
        user: PhoneUser('new'),
        startupResolved: true,
        loading: false,
        needsRegistration: true));
    expect((await container.read(generatorDirectoryProvider.future)).single.id,
        'g');
    auth.replace(const AuthState(startupResolved: true, loading: false));
    expect(container.read(generatorDirectoryProvider).isLoading, true);
    auth.replace(AuthState(
        user: PhoneUser('second'),
        startupResolved: true,
        loading: false,
        needsRegistration: true));
    expect((await container.read(generatorDirectoryProvider.future)).single.id,
        'g');
  });
  test(
      'tenant lists wait for profile and role then switch scope on membership change',
      () async {
    final db = FakeFirebaseFirestore(),
        auth = MultiAuthFixture(AuthState(
            user: PhoneUser('u'), startupResolved: true, loading: false));
    await db.collection('bills').doc('a').set({
      'generatorId': 'a',
      'userId': 'u',
      'amount': 20,
      'kwh': 10,
      'status': 'pending',
      'createdAt': 1,
      'month': 'يناير',
      'year': 2026
    });
    for (final gid in ['a', 'b']) {
      await db
          .collection('generators')
          .doc(gid)
          .set({'status': 'approved', 'subscriptionStatus': 'active'});
    }
    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(db),
      authProvider.overrideWith((ref) => auth)
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(allBillsProvider, (_, __) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(allBillsProvider).isLoading, true);
    AuthState ready(String gid) => AuthState(
        user: PhoneUser('u'),
        startupResolved: true,
        loading: false,
        profile: UserProfile(
            uid: 'u',
            name: 'مالك',
            role: UserRole.admin,
            generatorId: gid,
            createdAt: DateTime(2026)));
    auth.replace(ready('a'));
    expect((await container.read(allBillsProvider.future)).length, 1);
    auth.replace(ready('b'));
    expect(await container.read(allBillsProvider.future), isEmpty);
  });
}
