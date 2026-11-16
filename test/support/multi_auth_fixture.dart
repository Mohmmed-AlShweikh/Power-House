import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:generator_portal/providers/auth_provider.dart';

class PhoneUser implements User {
  @override
  final String uid;
  @override
  final String? phoneNumber;
  @override String? get email=>'test@example.com';
  @override bool get emailVerified=>true;
  PhoneUser(this.uid, [this.phoneNumber = '+970591234567']);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MultiAuthFixture extends StateNotifier<AuthState>
    implements AuthNotifier {
  String? submittedName, submittedSector, submittedGenerator;
  MultiAuthFixture(
      [super.initial = const AuthState(loading: false, startupResolved: true)]);
  void replace(AuthState value) => state = value;
  @override
  Future<void> enrollOwner(String name, String sector, {String phone='',String idNumber=''}) async {
    submittedName = name;
    submittedSector = sector;
  }

  @override
  Future<void> enrollConsumer(String name, String gid, {String phone='',String idNumber=''}) async {
    submittedName = name;
    submittedGenerator = gid;
  }

  @override
  Future<void> reloadProfile() async {}
  @override
  Future<void> signOut() async =>
      state = const AuthState(loading: false, startupResolved: true);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
