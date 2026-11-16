import 'package:firebase_auth/firebase_auth.dart';
import 'package:generator_portal/services/credential_service.dart';

class FakeCredentials implements CredentialService {
  @override
  bool hasPassword = true;
  @override
  bool hasPhone = true;
  @override
  String email = '123456789@id.generatorportal.app';
  @override
  String phone = '+970591234567';
  bool matches = true, reset = false, duplicate = false;
  String? linkedId, createdId;
  PhoneOperation? verifiedOperation;
  @override
  Future<void> createId(String id, String password, String confirm) async {
    final issue = passwordError(password, confirm, id, phone);
    if (issue != null) throw CredentialFailure(issue);
    createdId = id;
  }

  @override
  Future<void> loginId(String id, String password) async {}
  @override
  Future<void> sendPhone(String phone, PhoneOperation operation,
          {required void Function(String) sent,
          required void Function(String) failed,
          void Function()? verified}) async =>
      sent('test-session');
  @override
  void cancelPhone() {}
  @override
  Future<void> verifyPhone(
      String verificationId, String code, PhoneOperation operation) async {
    verifiedOperation = operation;
    hasPhone = true;
  }

  @override
  Future<void> linkId(String id, String password, String confirm) async {
    final issue = passwordError(password, confirm, id, phone);
    if (issue != null) throw CredentialFailure(issue);
    if (duplicate) throw const CredentialFailure(genericAuthError);
    linkedId = id;
    hasPassword = true;
  }

  @override
  Future<void> finishIdentity(String id) async {
    linkedId = id;
  }

  @override
  Future<bool> matchRecoveryId(String id) async => matches;
  @override
  Future<void> resetPassword(String id, String password, String confirm) async {
    final issue = passwordError(password, confirm, id, phone);
    if (issue != null) throw CredentialFailure(issue);
    reset = true;
  }

  @override
  Future<void> reauthenticatePassword(String password) async {}
  @override
  Future<void> changeIdentity(String id) async {
    linkedId = id;
  }

  @override
  Future<void> changePassword(String password, String confirm, String id) =>
      resetPassword(id, password, confirm);
}

class TestToken implements IdTokenResult {
  @override
  final DateTime? authTime;
  TestToken(this.authTime);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class TestUserInfo implements UserInfo {
  @override
  final String providerId;
  TestUserInfo(this.providerId);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class TestCredential implements UserCredential {
  @override
  final User user;
  TestCredential(this.user);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class TestAuth implements FirebaseAuth {
  @override
  TestUser? currentUser;
  final Map<String, TestUser> emails = {};
  final List<String> loginEmails = [];
  PhoneVerificationCompleted? automatic;
  String? requestedPhone;
  @override
  Future<void> verifyPhoneNumber(
      {String? phoneNumber,
      PhoneMultiFactorInfo? multiFactorInfo,
      required PhoneVerificationCompleted verificationCompleted,
      required PhoneVerificationFailed verificationFailed,
      required PhoneCodeSent codeSent,
      required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
      String? autoRetrievedSmsCodeForTesting,
      Duration timeout = const Duration(seconds: 30),
      int? forceResendingToken,
      MultiFactorSession? multiFactorSession}) async {
    requestedPhone = phoneNumber;
    automatic = verificationCompleted;
    codeSent('test-session', null);
  }

  @override
  Stream<User?> authStateChanges() => Stream.value(currentUser);
  @override
  Future<UserCredential> signInWithEmailAndPassword(
      {required String email, required String password}) async {
    loginEmails.add(email);
    final user = emails[email];
    if (user == null || user.password != password) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    currentUser = user;
    user.authTime = DateTime.now();
    return TestCredential(user);
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword(
      {required String email, required String password}) async {
    if (emails.containsKey(email)) {
      throw FirebaseAuthException(code: 'email-already-in-use');
    }
    final user = TestUser(this, 'new', email: email, password: password);
    emails[email] = user;
    currentUser = user;
    return TestCredential(user);
  }

  @override
  Future<void> signOut() async {
    currentUser = null;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class TestUser implements User {
  final TestAuth auth;
  @override
  final String uid;
  @override
  String? email;
  @override
  String? phoneNumber;
  String? password;
  DateTime authTime = DateTime.now();
  TestUser(this.auth, this.uid, {this.email, this.phoneNumber, this.password});
  @override
  List<UserInfo> get providerData => [
        if (email != null) TestUserInfo('password'),
        if (phoneNumber != null) TestUserInfo('phone')
      ];
  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async =>
      TestToken(authTime);
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async =>
      'fake-token-never-logged';
  @override
  Future<void> reload() async {}
  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    if (credential is PhoneAuthCredential) {
      phoneNumber = auth.requestedPhone;
      return TestCredential(this);
    }
    final c = credential as EmailAuthCredential;
    if (auth.emails[c.email] != null) {
      throw FirebaseAuthException(code: 'email-already-in-use');
    }
    email = c.email;
    password = c.password;
    auth.emails[c.email] = this;
    return TestCredential(this);
  }

  @override
  Future<UserCredential> reauthenticateWithCredential(
      AuthCredential credential) async {
    if (credential is PhoneAuthCredential) {
      authTime = DateTime.now();
      return TestCredential(this);
    }
    if ((credential as EmailAuthCredential).password != password) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    authTime = DateTime.now();
    return TestCredential(this);
  }

  @override
  Future<void> updateEmail(String newEmail) async {
    if (auth.emails[newEmail] != null) {
      throw FirebaseAuthException(code: 'email-already-in-use');
    }
    auth.emails.remove(email);
    email = newEmail;
    auth.emails[newEmail] = this;
  }

  @override
  Future<void> updatePassword(String value) async {
    password = value;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
