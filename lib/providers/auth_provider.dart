import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthState {
  final User? user;
  final UserProfile? profile;
  final bool loading;
  final bool isDemo;
  final String? verificationId;
  final String phoneNumber;
  final UserRole selectedRole;
  final String? error;

  const AuthState({
    this.user,
    this.profile,
    this.loading = true,
    this.isDemo = false,
    this.verificationId,
    this.phoneNumber = '',
    this.selectedRole = UserRole.consumer,
    this.error,
  });

  AuthState copyWith({
    User? user,
    UserProfile? profile,
    bool? loading,
    bool? isDemo,
    Object? verificationId = const _Sentinel(),
    String? phoneNumber,
    UserRole? selectedRole,
    Object? error = const _Sentinel(),
  }) =>
      AuthState(
        user: user ?? this.user,
        profile: profile ?? this.profile,
        loading: loading ?? this.loading,
        isDemo: isDemo ?? this.isDemo,
        verificationId: verificationId is _Sentinel
            ? this.verificationId
            : verificationId as String?,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        selectedRole: selectedRole ?? this.selectedRole,
        error: error is _Sentinel ? this.error : error as String?,
      );
}

class _Sentinel {
  const _Sentinel();
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  StreamSubscription? _authSub;
  StreamSubscription? _profileSub;

  static final _now = DateTime.now();

  static final _demoConsumer = UserProfile(
    uid: 'demo-consumer',
    phone: '0500000000',
    name: 'محمد أحمد',
    address: 'رام الله، حي البيرة',
    role: UserRole.consumer,
    subscriptionStatus: SubscriptionStatus.active,
    ampereLimit: 10,
    createdAt: _now,
  );

  static final _demoAdmin = UserProfile(
    uid: 'demo-admin',
    phone: '0599999999',
    name: 'أبو أحمد',
    address: 'رام الله',
    role: UserRole.admin,
    subscriptionStatus: SubscriptionStatus.active,
    ampereLimit: 0,
    createdAt: _now,
  );

  void _init() {
    _authSub = _auth.authStateChanges().listen((u) async {
      if (u == null) {
        state = state.copyWith(user: null, profile: null, loading: false);
        return;
      }
      state = state.copyWith(user: u, loading: true);
      await _loadProfile(u.uid);
    }, onError: (_) {
      state = state.copyWith(loading: false);
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (state.loading) state = state.copyWith(loading: false);
    });
  }

  Future<void> _loadProfile(String uid) async {
    _profileSub?.cancel();
    try {
      final ref = _db.collection('users').doc(uid);
      final snap = await ref.get();
      if (snap.exists) {
        final p = UserProfile.fromMap(uid, snap.data()!);
        state = state.copyWith(profile: p, loading: false);
        _profileSub = ref.snapshots().listen((s) {
          if (s.exists)
            state =
                state.copyWith(profile: UserProfile.fromMap(uid, s.data()!));
        });
      } else {
        state = state.copyWith(loading: false);
      }
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  void demoLogin(UserRole role) {
    state = state.copyWith(
      isDemo: true,
      profile: role == UserRole.admin ? _demoAdmin : _demoConsumer,
      loading: false,
    );
  }

  Future<bool> sendOtp(String phone, BuildContext context) async {
    final digits = phone.trim().replaceAll(RegExp(r'\D'), '');
    final normalized = digits.startsWith('0') ? digits : '0$digits';
    if (normalized.length < 9) {
      state = state.copyWith(error: 'الرجاء إدخال رقم هاتف صالح');
      return false;
    }

    state = state.copyWith(phoneNumber: normalized, error: null);

    // Try to look up the user's role in Firestore first.
    // If this fails (e.g. permissions), we still attempt to send the OTP.
    try {
      final query = await _db
          .collection('users')
          .where('phone', isEqualTo: normalized)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        state = state.copyWith(error: 'رقم الهاتف غير مسجل في النظام');
        return false;
      }

      final userMap = query.docs.first.data();
      final role =
          userMap['role'] == 'admin' ? UserRole.admin : UserRole.consumer;
      state = state.copyWith(selectedRole: role);
    } catch (_) {
      // Firestore lookup failed (rules/network) — continue anyway.
      // Role will be determined after successful sign-in via _ensureProfile.
    }

    final full = '+972${normalized.replaceFirst('0', '')}';
    final completer = Completer<bool>();

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: full,
        verificationCompleted: (cred) async {
          // Auto-verified (Android only). Sign in immediately.
          try {
            final r = await _auth.signInWithCredential(cred);
            if (r.user != null) await _ensureProfile(r.user!.uid);
            if (!completer.isCompleted) completer.complete(true);
          } catch (e) {
            if (!completer.isCompleted) completer.complete(false);
            state = state.copyWith(error: e.toString());
          }
        },
        verificationFailed: (e) {
          state = state.copyWith(error: e.message ?? 'فشل إرسال رمز التحقق');
          if (!completer.isCompleted) completer.complete(false);
        },
        codeSent: (vid, _) {
          state = state.copyWith(verificationId: vid);
          if (!completer.isCompleted) completer.complete(true);
        },
        // codeAutoRetrievalTimeout is Android-only; on web it may fire
        // immediately — do NOT complete with false here, the completer
        // is already resolved by codeSent or verificationFailed.
        codeAutoRetrievalTimeout: (_) {},
      );

      return completer.future;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<void> verifyOtp(String code) async {
    final vid = state.verificationId;
    if (vid == null) return;
    try {
      final cred =
          PhoneAuthProvider.credential(verificationId: vid, smsCode: code);
      final r = await _auth.signInWithCredential(cred);
      if (r.user != null) await _ensureProfile(r.user!.uid);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> _ensureProfile(String uid) async {
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();
    if (!snap.exists) {
      final p = UserProfile(
        uid: uid,
        phone: state.phoneNumber,
        name: '',
        address: '',
        role: state.selectedRole,
        subscriptionStatus: SubscriptionStatus.inactive,
        ampereLimit: state.selectedRole == UserRole.admin ? 0 : 10,
        createdAt: DateTime.now(),
      );
      await ref.set(p.toMap());
      state = state.copyWith(profile: p);
    }
  }

  Future<void> updateProfile({String? name, String? address}) async {
    if (state.isDemo) {
      final updated = state.profile!.copyWith(name: name, address: address);
      state = state.copyWith(profile: updated);
      return;
    }
    final uid = state.user?.uid;
    if (uid == null) return;
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (address != null) data['address'] = address;
    if (data.isNotEmpty) await _db.collection('users').doc(uid).update(data);
  }

  Future<void> signOut() async {
    _profileSub?.cancel();
    if (!state.isDemo) await _auth.signOut();
    state = const AuthState(loading: false);
  }

  void setRole(UserRole role) => state = state.copyWith(selectedRole: role);
  void clearError() => state = state.copyWith(error: null);

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
final demoModeProvider =
    Provider<bool>((ref) => ref.watch(authProvider).isDemo);
