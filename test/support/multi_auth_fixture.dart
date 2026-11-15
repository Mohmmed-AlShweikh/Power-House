import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:generator_portal/providers/auth_provider.dart';

class PhoneUser implements User {
  @override
  final String uid;
  @override
  final String? phoneNumber;
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
  Future<void> enrollOwner(String name, String sector) async {
    submittedName = name;
    submittedSector = sector;
  }

  @override
  Future<void> enrollConsumer(String name, String gid) async {
    submittedName = name;
    submittedGenerator = gid;
  }

  @override
  Future<void> signOut() async =>
      state = const AuthState(loading: false, startupResolved: true);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
