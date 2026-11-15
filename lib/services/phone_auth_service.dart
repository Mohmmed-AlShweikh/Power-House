import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class PhoneGateway {
  Future<void> send(String phone,
      {required void Function(String) codeSent,
      required void Function(String) failed});
  Future<void> verify(String verificationId, String code);
}

class FirebasePhoneGateway implements PhoneGateway {
  final FirebaseAuth auth;
  FirebasePhoneGateway(this.auth);
  @override
  Future<void> send(String phone,
          {required void Function(String) codeSent,
          required void Function(String) failed}) =>
      auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          try {
            await auth.signInWithCredential(credential);
          } on FirebaseAuthException {
            failed('تعذّر التحقق التلقائي. أدخل الرمز يدوياً.');
          }
        },
        verificationFailed: (_) =>
            failed('تعذّر إرسال الرمز. تحقق من الرقم وحاول مجدداً.'),
        codeSent: (id, _) => codeSent(id),
        codeAutoRetrievalTimeout: (_) {},
      );
  @override
  Future<void> verify(String verificationId, String code) =>
      auth.signInWithCredential(PhoneAuthProvider.credential(
          verificationId: verificationId, smsCode: code));
}

final phoneGatewayProvider = Provider<PhoneGateway>(
    (ref) => FirebasePhoneGateway(FirebaseAuth.instance));
