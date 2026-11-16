import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generator_portal/services/credential_service.dart';
import 'support/credential_fakes.dart';
import 'package:generator_portal/providers/auth_provider.dart';

void main() {
  test('password rules shared by enrollment, reset and management', () {
    for (final p in ['short1', 'abcdefgh', '123456789', '+970591234567']) {
      expect(passwordError(p, p, '123456789', '+970591234567'), isNotNull);
    }
    expect(passwordError('قوي12345', 'قوي12345', '123456789', '+970591234567'),
        isNull);
    expect(
        passwordError('Strong123', 'different', '123456789', '+970591234567'),
        isNotNull);
  });
  test('throttle blocks repeated failures and repeated OTP requests', () {
    var now = DateTime(2026);
    final throttle = AttemptThrottle(clock: () => now);
    throttle.otp();
    expect(throttle.otp, throwsA(isA<CredentialFailure>()));
    for (var i = 0; i < 5; i++) {
      throttle.failed();
    }
    expect(throttle.check, throwsA(isA<CredentialFailure>()));
    now = now.add(const Duration(seconds: 61));
    expect(throttle.check, returnsNormally);
    expect(throttle.otp, returnsNormally);
  });
  test('phone UID links ID login, persists only private ID claim and profile',
      () async {
    final db = FakeFirebaseFirestore(), auth = TestAuth();
    final user = TestUser(auth, 'same-uid', phoneNumber: '+970591234567');
    auth.currentUser = user;
    await db
        .collection('users')
        .doc(user.uid)
        .set({'phone': user.phoneNumber, 'role': 'user'});
    final service =
        FirebaseCredentialService(auth, db, throttle: AttemptThrottle());
    await service.linkId('123456789', 'Strong123', 'Strong123');
    await service.finishIdentity('123456789');
    await auth.signOut();
    await service.loginId('123456789', 'Strong123');
    expect(auth.currentUser?.uid, 'same-uid');
    expect((await db.collection('idIndex').doc('123456789').get()).data(),
        {'uid': 'same-uid'});
    final profile =
        (await db.collection('users').doc('same-uid').get()).data()!;
    expect(profile.containsKey('password'), false);
    expect(profile['credentialVersion'], 1);
  });
  test('duplicate ID never overwrites another UID claim', () async {
    final db = FakeFirebaseFirestore(), auth = TestAuth();
    auth.currentUser = TestUser(auth, 'second',
        email: idEmail('123456789'),
        phoneNumber: '+970591234567',
        password: 'Strong123');
    await db.collection('users').doc('second').set({'phone': '+970591234567'});
    await db.collection('idIndex').doc('123456789').set({'uid': 'first'});
    final service = FirebaseCredentialService(auth, db);
    await expectLater(
        service.finishIdentity('123456789'), throwsA(isA<CredentialFailure>()));
    expect(
        (await db.collection('idIndex').doc('123456789').get()).data()?['uid'],
        'first');
  });
  test('ID change atomically replaces index and retains UID', () async {
    final db = FakeFirebaseFirestore(), auth = TestAuth();
    auth.currentUser = TestUser(auth, 'u',
        email: idEmail('123456789'),
        phoneNumber: '+970591234567',
        password: 'Strong123');
    auth.emails[auth.currentUser!.email!] = auth.currentUser!;
    await db
        .collection('users')
        .doc('u')
        .set({'idNumber': '123456789', 'phone': '+970591234567'});
    await db.collection('idIndex').doc('123456789').set({'uid': 'u'});
    final service = FirebaseCredentialService(auth, db);
    await service.changeIdentity('987654321');
    expect(
        (await db.collection('idIndex').doc('123456789').get()).exists, false);
    expect(
        (await db.collection('idIndex').doc('987654321').get()).data()?['uid'],
        'u');
    await auth.signOut();
    await service.loginId('987654321', 'Strong123');
    expect(auth.currentUser?.uid, 'u');
  });
  test(
      'ID index collision rolls Auth email back without changing UID or profile',
      () async {
    final db = FakeFirebaseFirestore(), auth = TestAuth();
    final user = TestUser(auth, 'u',
        email: idEmail('123456789'),
        phoneNumber: '+970591234567',
        password: 'Strong123');
    auth.currentUser = user;
    auth.emails[user.email!] = user;
    await db
        .collection('users')
        .doc('u')
        .set({'idNumber': '123456789', 'phone': user.phoneNumber});
    await db.collection('idIndex').doc('123456789').set({'uid': 'u'});
    await db.collection('idIndex').doc('987654321').set({'uid': 'another'});
    await expectLater(
        FirebaseCredentialService(auth, db).changeIdentity('987654321'),
        throwsA(isA<CredentialFailure>()));
    expect(user.uid, 'u');
    expect(user.email, idEmail('123456789'));
    expect((await db.collection('users').doc('u').get()).data()?['idNumber'],
        '123456789');
  });
  test('mismatched recovery ID signs out and never changes password', () async {
    final db = FakeFirebaseFirestore(), auth = TestAuth();
    final user = TestUser(auth, 'u',
        email: idEmail('123456789'),
        phoneNumber: '+970591234567',
        password: 'Strong123');
    auth.currentUser = user;
    await db
        .collection('users')
        .doc('u')
        .set({'idNumber': '123456789', 'phone': user.phoneNumber});
    final service =
        FirebaseCredentialService(auth, db, throttle: AttemptThrottle());
    expect(await service.matchRecoveryId('987654321'), false);
    expect(auth.currentUser, isNull);
    expect(user.password, 'Strong123');
  });
  test('matching OTP identity resets password and signs out', () async {
    final db = FakeFirebaseFirestore(), auth = TestAuth();
    final user = TestUser(auth, 'u',
        email: idEmail('123456789'),
        phoneNumber: '+970591234567',
        password: 'Strong123');
    auth.currentUser = user;
    await db
        .collection('users')
        .doc('u')
        .set({'idNumber': '123456789', 'phone': user.phoneNumber});
    await FirebaseCredentialService(auth, db)
        .resetPassword('123456789', 'NewStrong123', 'NewStrong123');
    expect(user.password, 'NewStrong123');
    expect(auth.currentUser, isNull);
  });
  test('stale authentication refuses credential changes', () async {
    final auth = TestAuth();
    final user = TestUser(auth, 'u',
        email: idEmail('123456789'),
        phoneNumber: '+970591234567',
        password: 'Strong123');
    user.authTime = DateTime.now().subtract(const Duration(hours: 1));
    auth.currentUser = user;
    await expectLater(
        FirebaseCredentialService(auth, FakeFirebaseFirestore())
            .changePassword('NewStrong123', 'NewStrong123', '123456789'),
        throwsA(isA<CredentialFailure>()));
    expect(user.password, 'Strong123');
  });
  test(
      'legacy email remains reachable and login errors never enumerate accounts',
      () async {
    final auth = TestAuth(), db = FakeFirebaseFirestore();
    final user = TestUser(auth, 'legacy',
        email: '123456789@powershare.app', password: 'Strong123');
    auth.emails[user.email!] = user;
    await FirebaseCredentialService(auth, db, throttle: AttemptThrottle())
        .loginId('123456789', 'Strong123');
    expect(auth.currentUser?.uid, 'legacy');
    for (final code in [
      'user-not-found',
      'wrong-password',
      'email-already-in-use',
      'credential-already-in-use'
    ]) {
      expect(
          credentialError(FirebaseAuthException(code: code)), genericAuthError);
    }
  });
  test(
      'auth notifier requires missing method once and detects interrupted identity changes',
      () async {
    final db = FakeFirebaseFirestore(), auth = TestAuth();
    final user = TestUser(auth, 'u', phoneNumber: '+970591234567');
    auth.currentUser = user;
    await db.collection('users').doc('u').set({
      'name': 'مشترك',
      'role': 'user',
      'status': 'approved',
      'subscriptionStatus': 'active',
      'generatorId': 'g',
      'phone': user.phoneNumber
    });
    final notifier = AuthNotifier(auth: auth, firestore: db);
    addTearDown(notifier.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(notifier.state.startupResolved, true);
    expect(notifier.state.needsCredentialCompletion, true);
    await notifier.credentials.linkId('123456789', 'Strong123', 'Strong123');
    await notifier.credentials.finishIdentity('123456789');
    await notifier.reloadProfile();
    expect(notifier.state.needsCredentialCompletion, false);
    expect(notifier.state.user?.uid, 'u');
    await user.updateEmail(idEmail('987654321'));
    await notifier.reloadProfile();
    expect(notifier.state.needsCredentialCompletion, true);
    await notifier.credentials.changeIdentity('987654321');
    await notifier.reloadProfile();
    expect(notifier.state.needsCredentialCompletion, false);
    expect(notifier.state.profile?.idNumber, '987654321');
  });

  for (final cancelled in [false, true]) {
    test('instant Android OTP links the intended UID; cancelled=$cancelled',
        () async {
      final auth = TestAuth(), db = FakeFirebaseFirestore();
      final user = TestUser(auth, 'same',
          email: idEmail('123456789'), password: 'Strong123');
      auth.currentUser = user;
      final service =
          FirebaseCredentialService(auth, db, throttle: AttemptThrottle());
      var completed = 0;
      await service.sendPhone('+970591234567', PhoneOperation.link,
          sent: (_) {},
          failed: (_) => fail('unexpected OTP error'),
          verified: () => completed++);
      if (cancelled) {
        service.cancelPhone();
      }
      auth.automatic!(PhoneAuthProvider.credential(
          verificationId: 'test-session', smsCode: '123456'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(auth.currentUser?.uid, 'same');
      expect(completed, cancelled ? 0 : 1);
      expect(user.phoneNumber, cancelled ? isNull : '+970591234567');
    });
  }
  test(
      'ID login surfaces client throttle instead of a misleading network error',
      () async {
    final notifier =
        AuthNotifier(auth: TestAuth(), firestore: FakeFirebaseFirestore());
    addTearDown(notifier.dispose);
    for (var i = 0; i < 5; i++) {
      await notifier.login('123456789', 'wrong');
    }
    expect(
        await notifier.login('123456789', 'wrong'), contains('محاولات كثيرة'));
  });
}
