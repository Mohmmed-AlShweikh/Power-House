import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tenant_provider.dart';

bool realEmail(String value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim()) &&
    !value.trim().toLowerCase().endsWith('@powershare.app') &&
    !value.trim().toLowerCase().endsWith('@id.generatorportal.app');
bool validNationalId(String value) => RegExp(r'^\d{9,10}$').hasMatch(value);
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
    return 'لا تستخدم الهوية أو الهاتف كلمة مرور';
  }
  return password == confirm ? null : 'كلمتا المرور غير متطابقتين';
}

const passwordRules =
    '8 أحرف على الأقل • حرف ورقم • تختلف عن الهوية والهاتف • التأكيد مطابق';
const genericAuthError =
    'تعذّر إكمال الطلب. تحقق من البيانات أو الاتصال وحاول مجدداً.';
String credentialError(Object error) {
  if (error is CredentialFailure) return error.message;
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'too-many-requests' => 'محاولات كثيرة. انتظر قليلاً ثم حاول مجدداً.',
      'network-request-failed' =>
        'تعذّر الاتصال. تحقق من الإنترنت وحاول مجدداً.',
      'requires-recent-login' =>
        'أعد التحقق بكلمة المرور الحالية ثم كرر التغيير.',
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
  DateTime? blockedUntil, lastEmail;
  AttemptThrottle({DateTime Function()? clock}) : now = clock ?? DateTime.now;
  void check() {
    if (blockedUntil != null && now().isBefore(blockedUntil!)) {
      throw const CredentialFailure(
          'محاولات كثيرة. انتظر دقيقة ثم حاول مجدداً.');
    }
  }

  void message() {
    check();
    if (lastEmail != null &&
        now().difference(lastEmail!) < const Duration(seconds: 60)) {
      throw const CredentialFailure('انتظر دقيقة قبل طلب رسالة جديدة.');
    }
    lastEmail = now();
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

abstract class CredentialService {
  String get email;
  bool get verified => false;
  Future<void> loginEmail(String email, String password);
  Future<void> registerEmail(String email, String password, String confirm);
  Future<void> sendVerification();
  Future<void> refresh();
  Future<void> sendReset(String email);
  Future<void> reauthenticatePassword(String password);
  Future<void> finishAccount({String id = '', String phone = ''});
  Future<void> changePassword(String password, String confirm, String id,
      {String phone = ''});
}

class FirebaseCredentialService extends CredentialService {
  final FirebaseAuth auth;
  final FirebaseFirestore db;
  final AttemptThrottle throttle;
  FirebaseCredentialService(this.auth, this.db, {AttemptThrottle? throttle})
      : throttle = throttle ?? sharedCredentialThrottle;
  User get user =>
      auth.currentUser ?? (throw const CredentialFailure(genericAuthError));
  @override
  String get email => auth.currentUser?.email ?? '';
  @override
  bool get verified =>
      auth.currentUser?.emailVerified == true && realEmail(email);
  void checkEmail(String value) {
    if (!realEmail(value)) {
      throw const CredentialFailure(
          'أدخل بريداً إلكترونياً حقيقياً يمكنك فتحه');
    }
  }

  @override
  Future<void> loginEmail(String value, String password) async {
    checkEmail(value);
    throttle.check();
    try {
      await auth.signInWithEmailAndPassword(
          email: value.trim(), password: password);
      throttle.succeeded();
    } catch (_) {
      throttle.failed();
      rethrow;
    }
  }

  @override
  Future<void> registerEmail(
      String value, String password, String confirm) async {
    checkEmail(value);
    final issue = passwordError(password, confirm, '', '');
    if (issue != null) throw CredentialFailure(issue);
    throttle.check();
    try {
      await auth.createUserWithEmailAndPassword(
          email: value.trim(), password: password);
      throttle.succeeded();
      await sendVerification();
    } catch (_) {
      throttle.failed();
      rethrow;
    }
  }

  @override
  Future<void> sendVerification() async {
    throttle.message();
    await user.sendEmailVerification();
  }

  @override
  Future<void> refresh() async {
    await user.reload();
    await user.getIdToken(true);
  }

  @override
  Future<void> sendReset(String value) async {
    checkEmail(value);
    throttle.message();
    try {
      await auth.sendPasswordResetEmail(email: value.trim());
    } on FirebaseAuthException catch (error) {
      // Do not reveal whether an email account exists.
      if (!['user-not-found', 'invalid-email'].contains(error.code)) rethrow;
    }
  }

  Future<void> requireRecent() async {
    final uid = user.uid;
    final token = await user.getIdTokenResult(true);
    if (auth.currentUser?.uid != uid ||
        token.authTime == null ||
        DateTime.now().difference(token.authTime!) >
            const Duration(minutes: 5)) {
      throw const CredentialFailure(
          'أعد التحقق بكلمة المرور الحالية ثم كرر التغيير.');
    }
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
  Future<void> finishAccount({String id = '', String phone = ''}) async {
    if (!verified ||
        (id.isNotEmpty && !validNationalId(id)) ||
        phone.length > 32) {
      throw const CredentialFailure('تحقق من البريد وأدخل بيانات صحيحة');
    }
    await requireRecent();
    final uid = user.uid, address = email;
    await db.collection('users').doc(uid).update({
      'email': address,
      'phone': phone,
      'credentialVersion': 2,
      'idNumber': id
    });
  }

  @override
  Future<void> changePassword(String password, String confirm, String id,
      {String phone = ''}) async {
    final issue = passwordError(password, confirm, id, phone);
    if (issue != null) throw CredentialFailure(issue);
    await requireRecent();
    await user.updatePassword(password);
  }
}

final credentialServiceProvider = Provider<CredentialService>((ref) =>
    FirebaseCredentialService(
        FirebaseAuth.instance, ref.watch(firestoreProvider)));
final credentialFlowProvider = StateProvider<bool>((ref) => false);
final loginNoticeProvider = StateProvider<String?>((ref) => null);
