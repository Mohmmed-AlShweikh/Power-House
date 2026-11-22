import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:generator_portal/services/credential_service.dart';
import 'package:generator_portal/providers/auth_provider.dart';
import 'support/credential_fakes.dart';

void main() {
  test('only real email is accepted; phone and ID are not login', () {
    expect(realEmail('test@example.com'), true);
    for (final value in [
      '123456789',
      '+970591234567',
      '123456789@powershare.app',
      'x@id.generatorportal.app'
    ]) {
      expect(realEmail(value), false);
    }
  });
  test(
      'email signup sends verification and keeps profile absent until verified',
      () async {
    final auth = TestAuth(), db = FakeFirebaseFirestore();
    final service =
        FirebaseCredentialService(auth, db, throttle: AttemptThrottle());
    await service.registerEmail('new@example.com', 'Strong123', 'Strong123');
    expect(auth.currentUser!.emailVerified, false);
    expect(auth.currentUser!.verificationMails, 1);
    expect((await db.collection('users').get()).docs, isEmpty);
    final notifier = AuthNotifier(auth: auth, firestore: db);
    addTearDown(notifier.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(notifier.state.needsEmailVerification, true);
    expect(notifier.state.profile, isNull);
    auth.currentUser!.emailVerified = true;
    await notifier.reloadProfile();
    expect(notifier.state.needsEmailVerification, false);
    expect(notifier.state.needsRegistration, true);
  });
  test('email login uses same account; wrong credentials are generic',
      () async {
    final auth = TestAuth(), db = FakeFirebaseFirestore();
    final user = TestUser(auth, 'u');
    auth.emails[user.email!] = user;
    final service =
        FirebaseCredentialService(auth, db, throttle: AttemptThrottle());
    await service.loginEmail('test@example.com', 'Strong123');
    expect(auth.currentUser!.uid, 'u');
    await expectLater(
        service.loginEmail('test@example.com', 'wrong'), throwsA(anything));
  });
  test('reset sends email; validation and throttle are bounded', () async {
    final auth = TestAuth();
    final service = FirebaseCredentialService(auth, FakeFirebaseFirestore(),
        throttle: AttemptThrottle());
    await service.sendReset('test@example.com');
    expect(auth.resetAddress, 'test@example.com');
    await expectLater(service.sendReset('test@example.com'),
        throwsA(isA<CredentialFailure>()));
    expect(passwordError('weak', 'weak', '', ''), isNotNull);
    expect(passwordError('Strong123', 'Strong123', '', ''), isNull);
  });
  test('profile contact fields never change auth phone or identity', () async {
    final auth = TestAuth(), db = FakeFirebaseFirestore();
    auth.currentUser = TestUser(auth, 'u');
    await db.collection('users').doc('u').set({'role': 'user'});
    await FirebaseCredentialService(auth, db)
        .finishAccount(id: '123456789', phone: '0591234567');
    expect((await db.collection('users').doc('u').get()).data()?['phone'],
        '0591234567');
    expect(auth.currentUser!.phoneNumber, isNull);
    expect(auth.currentUser!.email, 'test@example.com');
  });
  test('no SMS/ID/demo auth entrypoints remain in source', () {
    final code = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.readAsStringSync())
        .join('\n');
    for (final forbidden in [
      'verifyPhoneNumber(',
      'PhoneAuthProvider',
      'demoLogin(',
      'loginId(',
      'linkId('
    ]) {
      expect(code.contains(forbidden), false, reason: forbidden);
    }
  });
}
