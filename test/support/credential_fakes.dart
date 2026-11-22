import 'package:firebase_auth/firebase_auth.dart';
import 'package:generator_portal/services/credential_service.dart';

class FakeCredentials extends CredentialService {
  @override
  String email = 'test@example.com';
  @override
  bool verified = true;
  String? submittedEmail, resetEmail;
  bool verificationSent = false;
  @override
  Future<void> loginEmail(String email, String password) async {
    submittedEmail = email;
  }

  @override
  Future<void> registerEmail(
      String email, String password, String confirm) async {
    final issue = passwordError(password, confirm, '', '');
    if (issue != null) throw CredentialFailure(issue);
    submittedEmail = email;
  }

  @override
  Future<void> sendVerification() async {
    verificationSent = true;
  }

  @override
  Future<void> refresh() async {}
  @override
  Future<void> sendReset(String email) async {
    resetEmail = email;
  }

  @override
  Future<void> reauthenticatePassword(String password) async {}
  @override
  Future<void> finishAccount({String id = '', String phone = ''}) async {}
  @override
  Future<void> changePassword(String password, String confirm, String id,
      {String phone = ''}) async {}
}

class TestToken implements IdTokenResult {
  @override
  final DateTime? authTime;
  TestToken(this.authTime);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class TestInfo implements UserInfo {
  @override
  final String providerId = 'password';
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
  String? resetAddress;
  @override
  Stream<User?> authStateChanges() => Stream.value(currentUser);
  @override
  Future<UserCredential> createUserWithEmailAndPassword(
      {required String email, required String password}) async {
    if (emails.containsKey(email)) {
      throw FirebaseAuthException(code: 'email-already-in-use');
    }
    final user = TestUser(this, 'new',
        email: email, password: password, emailVerified: false);
    emails[email] = user;
    currentUser = user;
    return TestCredential(user);
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword(
      {required String email, required String password}) async {
    final user = emails[email];
    if (user == null || user.password != password) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    currentUser = user;
    return TestCredential(user);
  }

  @override
  Future<void> sendPasswordResetEmail(
      {required String email, ActionCodeSettings? actionCodeSettings}) async {
    resetAddress = email;
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
  final String? email;
  @override
  bool emailVerified;
  String password;
  int verificationMails = 0;
  DateTime authTime = DateTime.now();
  TestUser(this.auth, this.uid,
      {this.email = 'test@example.com',
      this.password = 'Strong123',
      this.emailVerified = true});
  @override
  List<UserInfo> get providerData => [TestInfo()];
  @override
  String? get phoneNumber => null;
  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async =>
      TestToken(authTime);
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'test-token';
  @override
  Future<void> reload() async {}
  @override
  Future<void> sendEmailVerification(
      [ActionCodeSettings? actionCodeSettings]) async {
    verificationMails++;
  }

  @override
  Future<UserCredential> reauthenticateWithCredential(
      AuthCredential credential) async {
    if ((credential as EmailAuthCredential).password != password) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    authTime = DateTime.now();
    return TestCredential(this);
  }

  @override
  Future<void> updatePassword(String value) async {
    password = value;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
