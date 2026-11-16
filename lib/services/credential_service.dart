import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tenant_provider.dart';
import 'firestore_reads.dart';

// Preserve the existing Auth namespace: a second domain could duplicate an ID
// across two Firebase accounts. The address is never used as an inbox.
String idEmail(String id) => '${id.trim()}@powershare.app';
bool validNationalId(String id) => RegExp(r'^\d{9,10}$').hasMatch(id);
String? passwordError(
    String password, String confirm, String id, String phone) {
  if (password.length < 8 ||
      !RegExp(r'\p{L}', unicode: true).hasMatch(password) ||
      !RegExp(r'\d').hasMatch(password)) {
    return 'استخدم 8 أحرف على الأقل، تشمل حرفاً ورقماً';
  }
  if (password == id ||
      password == phone ||
      password == phone.replaceAll(RegExp(r'\D'), '')) {
    return 'لا تستخدم رقم الهوية أو الهاتف كلمة مرور';
  }
  return password == confirm ? null : 'كلمتا المرور غير متطابقتين';
}

const passwordRules =
    '8 أحرف على الأقل • حرف ورقم • تختلف عن الهوية والهاتف • التأكيد مطابق';
const genericAuthError = 'تعذّر التحقق من البيانات. تحقق منها وحاول مجدداً.';
String credentialError(Object error) {
  if (error is CredentialFailure) return error.message;
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-verification-code' => 'رمز التحقق غير صحيح',
      'session-expired' ||
      'invalid-verification-id' =>
        'انتهت صلاحية الرمز. اطلب رمزاً جديداً.',
      'too-many-requests' => 'محاولات كثيرة. انتظر قليلاً ثم حاول مجدداً.',
      'network-request-failed' =>
        'تعذّر الاتصال. تحقق من الإنترنت وحاول مجدداً.',
      'requires-recent-login' => 'أعد التحقق من هويتك ثم كرر التغيير.',
      'operation-not-allowed' => 'تعذّر إكمال العملية. تواصل مع مسؤول التطبيق.',
      _ => genericAuthError,
    };
  }
  return genericAuthError;
}

class CredentialFailure implements Exception {
  final String message;
  const CredentialFailure(this.message);
}

class AttemptThrottle {
  final DateTime Function() now;
  int failures = 0;
  DateTime? blockedUntil, lastOtp;
  AttemptThrottle({DateTime Function()? clock}) : now = clock ?? DateTime.now;
  void check() {
    if (blockedUntil != null && now().isBefore(blockedUntil!)) {
      throw const CredentialFailure(
          'محاولات كثيرة. انتظر دقيقة ثم حاول مجدداً.');
    }
  }

  void otp() {
    check();
    if (lastOtp != null &&
        now().difference(lastOtp!) < const Duration(seconds: 60)) {
      throw const CredentialFailure('انتظر دقيقة قبل طلب رمز جديد.');
    }
    lastOtp = now();
  }

  void failed() {
    if (++failures >= 5) {
      blockedUntil = now().add(const Duration(minutes: 1));
      failures = 0;
    }
  }

  void succeeded() {
    failures = 0;
    blockedUntil = null;
  }
}

final sharedCredentialThrottle = AttemptThrottle();

enum PhoneOperation { signIn, link, reauthenticate, change }

abstract class CredentialService {
  bool get hasPassword;
  bool get hasPhone;
  String get email;
  String get phone;
  Future<void> loginId(String id, String password);
  Future<void> createId(String id, String password, String confirm);
  Future<void> sendPhone(String phone, PhoneOperation operation,
      {required void Function(String) sent,
      required void Function(String) failed,
      void Function()? verified});
  void cancelPhone();
  Future<void> verifyPhone(
      String verificationId, String code, PhoneOperation operation);
  Future<void> linkId(String id, String password, String confirm);
  Future<void> finishIdentity(String id);
  Future<bool> matchRecoveryId(String id);
  Future<void> resetPassword(String id, String password, String confirm);
  Future<void> reauthenticatePassword(String password);
  Future<void> changeIdentity(String id);
  Future<void> changePassword(String password, String confirm, String id);
}

class FirebaseCredentialService implements CredentialService {
  final FirebaseAuth auth;
  final FirebaseFirestore db;
  final AttemptThrottle throttle;
  int _phoneGeneration = 0;
  String? _requestedUid;
  @override
  void cancelPhone() {
    _phoneGeneration++;
  }

  FirebaseCredentialService(this.auth, this.db, {AttemptThrottle? throttle})
      : throttle = throttle ?? sharedCredentialThrottle;
  User get user =>
      auth.currentUser ?? (throw const CredentialFailure(genericAuthError));
  @override
  bool get hasPassword =>
      auth.currentUser?.providerData.any((p) => p.providerId == 'password') ??
      false;
  @override
  bool get hasPhone => auth.currentUser?.phoneNumber != null;
  @override
  String get email => auth.currentUser?.email ?? '';
  @override
  String get phone => auth.currentUser?.phoneNumber ?? '';
  void validate(String id, String password, String confirm) {
    if (!validNationalId(id)) {
      throw const CredentialFailure('أدخل رقم هوية من 9 أو 10 أرقام');
    }
    final error = passwordError(password, confirm, id, phone);
    if (error != null) throw CredentialFailure(error);
  }

  @override
  Future<void> loginId(String id, String password) async {
    throttle.check();
    try {
      await auth.signInWithEmailAndPassword(
          email: idEmail(id), password: password);
      throttle.succeeded();
    } catch (_) {
      throttle.failed();
      rethrow;
    }
  }

  @override
  Future<void> createId(String id, String password, String confirm) async {
    validate(id, password, confirm);
    throttle.check();
    try {
      await auth.createUserWithEmailAndPassword(
          email: idEmail(id), password: password);
      throttle.succeeded();
    } catch (_) {
      throttle.failed();
      rethrow;
    }
  }

  Future<void> applyPhone(
      PhoneAuthCredential credential, PhoneOperation operation) async {
    switch (operation) {
      case PhoneOperation.signIn:
        await auth.signInWithCredential(credential);
      case PhoneOperation.link:
        if (hasPhone) {
          await user.reauthenticateWithCredential(credential);
        } else {
          await user.linkWithCredential(credential);
        }
      case PhoneOperation.reauthenticate:
        await user.reauthenticateWithCredential(credential);
      case PhoneOperation.change:
        await requireRecent();
        await user.updatePhoneNumber(credential);
    }
    await user.reload();
    await user.getIdToken(true);
  }

  @override
  Future<void> sendPhone(String value, PhoneOperation operation,
      {required void Function(String) sent,
      required void Function(String) failed,
      void Function()? verified}) async {
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value)) {
      throw const CredentialFailure('أدخل الهاتف مع رمز الدولة');
    }
    throttle.otp();
    final generation = ++_phoneGeneration;
    final expectedUid = auth.currentUser?.uid;
    _requestedUid = expectedUid;
    await auth.verifyPhoneNumber(
        phoneNumber: value,
        verificationCompleted: (credential) async {
          if (generation != _phoneGeneration) return;
          if (operation != PhoneOperation.signIn &&
              auth.currentUser?.uid != expectedUid) {
            failed(genericAuthError);
            return;
          }
          try {
            await applyPhone(credential, operation);
            if (generation == _phoneGeneration) {
              throttle.succeeded();
              verified?.call();
            }
          } catch (error) {
            if (generation == _phoneGeneration) {
              throttle.failed();
              failed(credentialError(error));
            }
          }
        },
        verificationFailed: (error) {
          if (generation != _phoneGeneration) return;
          throttle.failed();
          failed(credentialError(error));
        },
        codeSent: (id, _) {
          if (generation == _phoneGeneration) sent(id);
        },
        codeAutoRetrievalTimeout: (_) {});
  }

  @override
  Future<void> verifyPhone(
      String verificationId, String code, PhoneOperation operation) async {
    throttle.check();
    _phoneGeneration++;
    if (operation != PhoneOperation.signIn &&
        auth.currentUser?.uid != _requestedUid) {
      throw const CredentialFailure(genericAuthError);
    }
    try {
      await applyPhone(
          PhoneAuthProvider.credential(
              verificationId: verificationId, smsCode: code),
          operation);
      throttle.succeeded();
    } catch (_) {
      throttle.failed();
      rethrow;
    }
  }

  Future<void> requireRecent() async {
    final token = await user.getIdTokenResult(true);
    if (token.authTime == null ||
        DateTime.now().difference(token.authTime!) >
            const Duration(minutes: 5)) {
      throw const CredentialFailure('أعد التحقق من هويتك ثم كرر التغيير.');
    }
  }

  @override
  Future<void> linkId(String id, String password, String confirm) async {
    validate(id, password, confirm);
    await requireRecent();
    if (!hasPassword) {
      await user.linkWithCredential(
          EmailAuthProvider.credential(email: idEmail(id), password: password));
      await user.reload();
      await user.getIdToken(true);
    } else if (email != idEmail(id)) {
      throw const CredentialFailure(genericAuthError);
    }
  }

  @override
  Future<void> finishIdentity(String id) async {
    if (!validNationalId(id) ||
        !hasPassword ||
        !hasPhone ||
        (email != idEmail(id))) {
      throw const CredentialFailure(genericAuthError);
    }
    await requireRecent();
    final uid = user.uid;
    await db.runTransaction((tx) async {
      final profileRef = db.collection('users').doc(uid);
      final profile = await tx.get(profileRef);
      if (!profile.exists) {
        throw const CredentialFailure('أكمل بيانات التسجيل أولاً');
      }
      final index = db.collection('idIndex').doc(id);
      final claim = await tx.get(index);
      if (claim.exists && claim.data()?['uid'] != uid) {
        throw const CredentialFailure(
            'تعذّر اعتماد رقم الهوية. تحقق من البيانات.');
      }
      final old = profile.data()?['idNumber'] as String? ?? '';
      DocumentSnapshot<Map<String, dynamic>>? oldClaim;
      if (validNationalId(old) && old != id) {
        oldClaim = await tx.get(db.collection('idIndex').doc(old));
      }
      tx.set(index, {'uid': uid});
      tx.update(
          profileRef, {'idNumber': id, 'phone': phone, 'credentialVersion': 1});
      if (oldClaim?.data()?['uid'] == uid) tx.delete(oldClaim!.reference);
    });
  }

  @override
  Future<bool> matchRecoveryId(String id) async {
    final uid = user.uid;
    final registeredPhone = phone;
    final doc = await retryFirestore(() => Stream.fromFuture(db
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server)))).first;
    final matches = doc.exists &&
        auth.currentUser?.uid == uid &&
        doc.data()?['idNumber'] == id &&
        doc.data()?['phone'] == registeredPhone;
    if (!matches) {
      throttle.failed();
      if (auth.currentUser?.uid == uid) await auth.signOut();
    }
    return matches;
  }

  @override
  Future<void> resetPassword(String id, String password, String confirm) async {
    validate(id, password, confirm);
    // Recheck at submission; UI state alone never authorizes the reset.
    if (!await matchRecoveryId(id)) {
      throw const CredentialFailure(genericAuthError);
    }
    if (!hasPassword) {
      await linkId(id, password, confirm);
    }
    await finishIdentity(id);
    await requireRecent();
    await user.updatePassword(password);
    await auth.signOut();
  }

  @override
  Future<void> reauthenticatePassword(String password) async {
    throttle.check();
    try {
      await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: email, password: password));
      await user.getIdToken(true);
      throttle.succeeded();
    } catch (_) {
      throttle.failed();
      rethrow;
    }
  }

  @override
  Future<void> changeIdentity(String id) async {
    if (!validNationalId(id)) {
      throw const CredentialFailure('أدخل رقم هوية من 9 أو 10 أرقام');
    }
    await requireRecent();
    final oldEmail = email;
    if (oldEmail != idEmail(id)) {
      // Synthetic addresses have no inbox. The SDK's direct update is required;
      // projects forbidding it need a trusted admin backend, never a client bypass.
      // ignore: deprecated_member_use
      await user.updateEmail(idEmail(id));
      await user.reload();
      await user.getIdToken(true);
    }
    try {
      await finishIdentity(id);
    } catch (_) {
      // Keep the old alias if the atomic profile/index commit is rejected.
      if (email != oldEmail) {
        try {
          // ignore: deprecated_member_use
          await user.updateEmail(oldEmail);
          await user.reload();
          await user.getIdToken(true);
        } catch (_) {
          throw const CredentialFailure(
              'تعذّر حفظ الهوية. أعد التحقق واستكمل الربط من الحساب نفسه.');
        }
      }
      rethrow;
    }
  }

  @override
  Future<void> changePassword(
      String password, String confirm, String id) async {
    validate(id, password, confirm);
    await requireRecent();
    await user.updatePassword(password);
  }
}

final credentialServiceProvider = Provider<CredentialService>((ref) =>
    FirebaseCredentialService(
        FirebaseAuth.instance, ref.watch(firestoreProvider)));
final credentialFlowProvider = StateProvider<bool>((ref) => false);
final loginNoticeProvider = StateProvider<String?>((ref) => null);
