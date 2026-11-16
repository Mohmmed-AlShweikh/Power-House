import 'credential_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class PhoneGateway {
  Future<void> send(String phone,
      {required void Function(String) codeSent,
      required void Function(String) failed});
  Future<void> verify(String verificationId, String code);
  void cancel();
}

class FirebasePhoneGateway implements PhoneGateway {
  final CredentialService credentials;
  FirebasePhoneGateway(this.credentials);
  @override
  Future<void> send(String phone,
          {required void Function(String) codeSent,
          required void Function(String) failed}) =>
      credentials.sendPhone(phone, PhoneOperation.signIn,
          sent: codeSent, failed: failed);
  @override
  void cancel() => credentials.cancelPhone();
  @override
  Future<void> verify(String verificationId, String code) =>
      credentials.verifyPhone(verificationId, code, PhoneOperation.signIn);
}

final phoneGatewayProvider = Provider<PhoneGateway>(
    (ref) => FirebasePhoneGateway(ref.watch(credentialServiceProvider)));
