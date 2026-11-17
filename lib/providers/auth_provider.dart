import '../services/contact_fields.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/tenant_store.dart';
import '../services/cached_profile.dart';
import '../services/credential_service.dart';
import '../services/firestore_reads.dart';

class AuthState {
  final User? user;
  final UserProfile? profile;
  final bool loading;
  // Remains false until the first auth event and profile check finish.
  final bool startupResolved;
  final bool needsRegistration;
  final bool needsEmailVerification;
  final String? error;

  const AuthState({
    this.user,
    this.profile,
    this.loading = true,
    this.startupResolved = false,
    this.needsRegistration = false,
    this.needsEmailVerification = false,
    this.error,
  });

  AuthState copyWith({
    Object? user = const _Sentinel(),
    Object? profile = const _Sentinel(),
    bool? loading,
    bool? startupResolved,
    bool? needsRegistration,
    bool? needsEmailVerification,
    Object? error = const _Sentinel(),
  }) =>
      AuthState(
        user: user is _Sentinel ? this.user : user as User?,
        profile: profile is _Sentinel ? this.profile : profile as UserProfile?,
        loading: loading ?? this.loading,
        startupResolved: startupResolved ?? this.startupResolved,
        needsRegistration: needsRegistration ?? this.needsRegistration,
        needsEmailVerification:
            needsEmailVerification ?? this.needsEmailVerification,
        error: error is _Sentinel ? this.error : error as String?,
      );
}

class _Sentinel {
  const _Sentinel();
}

// ── Notifier ───────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance,
        super(const AuthState()) {
    _init();
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  Timer? _startupTimer;
  StreamSubscription? _authSub;
  StreamSubscription? _profileSub;

  late final credentials = FirebaseCredentialService(_auth, _db);

  void _init() async {
    // Timeout safety net
    _startupTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && state.loading) state = state.copyWith(loading: false);
    });

    // Privileged accounts are provisioned only by a trusted administrator.
    _authSub = _auth.authStateChanges().listen((u) async {
      if (u == null) {
        _profileSub?.cancel();
        _profileSub = null;
        state = state.copyWith(
            user: null,
            profile: null,
            loading: false,
            startupResolved: true,
            needsRegistration: false,
            needsEmailVerification: false,
            error: const _Sentinel());
        return;
      }
      state = state.copyWith(
          user: u,
          profile: null,
          loading: true,
          startupResolved: false,
          needsRegistration: false);
      await _loadAndCheckProfile(u.uid);
      if (mounted && _auth.currentUser?.uid == u.uid) {
        state = state.copyWith(startupResolved: true);
      }
    }, onError: (_) {
      state = state.copyWith(loading: false, startupResolved: true);
    });
  }

  Future<void> _loadAndCheckProfile(String uid) async {
    await _profileSub?.cancel();
    if (!credentials.verified) {
      if (mounted) {
        state = state.copyWith(
            user: _auth.currentUser,
            profile: null,
            needsEmailVerification: true,
            needsRegistration: false,
            loading: false,
            startupResolved: true);
      }
      return;
    }
    void apply(DocumentSnapshot<Map<String, dynamic>> doc) {
      if (!mounted || _auth.currentUser?.uid != uid) return;
      if (!doc.exists) {
        state = state.copyWith(
            user: _auth.currentUser,
            profile: null,
            needsEmailVerification: !credentials.verified,
            needsRegistration: true,
            loading: false);
        return;
      }
      state = state.copyWith(
          user: _auth.currentUser,
          profile: UserProfile.fromMap(uid, doc.data()!),
          needsEmailVerification: !credentials.verified,
          needsRegistration: false,
          loading: false,
          error: null);
    }

    try {
      // SDK cache is scoped to this Firebase UID, not a role in preferences.
      // Server snapshots keep validating approval/membership after fast routing.
      final cached = await readCachedProfile(_db, uid);
      if (cached != null && cached.exists) {
        apply(cached);
        if (mounted && _auth.currentUser?.uid == uid) {
          state = state.copyWith(startupResolved: true);
        }
      } else {
        apply(await retryFirestore(() => Stream.fromFuture(_db
            .collection('users')
            .doc(uid)
            .get(const GetOptions(source: Source.server)))).first);
      }
      if (!mounted || _auth.currentUser?.uid != uid) return;
      _profileSub =
          retryFirestore(() => _db.collection('users').doc(uid).snapshots())
              .listen(apply, onError: (_) {
        if (mounted && _auth.currentUser?.uid == uid) {
          state = state.copyWith(
              loading: false, error: 'تعذّر تحميل الحساب. حاول مجدداً.');
        }
      });
    } catch (_) {
      if (mounted && _auth.currentUser?.uid == uid) {
        state = state.copyWith(
            loading: false, error: 'تعذّر تحميل الحساب. حاول مجدداً.');
      }
    }
  }

  // ── Public Methods ──────────────────────────────────────────────────────────

  /// Returns null on success, Arabic error message on failure.
  Future<String?> login(String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await credentials.loginEmail(email, password);
      // _loadAndCheckProfile is triggered by the auth listener
      return null;
    } on FirebaseAuthException catch (e) {
      final msg = credentialError(e);
      state = state.copyWith(loading: false, error: msg);
      return msg;
    } catch (error) {
      final msg = credentialError(error);
      state = state.copyWith(loading: false, error: msg);
      return msg;
    }
  }

  Future<void> enrollOwner(String name, String sector,
      {String phone = '', String idNumber = ''}) async {
    final user = _auth.currentUser;
    if (user == null || !credentials.verified) {
      throw const CredentialFailure('تحقق من البريد أولاً');
    }
    await TenantStore(_db, () => user.uid).enrollOwner(
        uid: user.uid,
        phone: phone,
        name: name,
        sector: sector,
        idNumber: idNumber.isEmpty ? null : idNumber,
        email: user.email!);
    await _loadAndCheckProfile(user.uid);
  }

  Future<void> enrollConsumer(String name, String gid,
      {String phone = '', String idNumber = ''}) async {
    final user = _auth.currentUser;
    if (user == null || !credentials.verified) {
      throw const CredentialFailure('تحقق من البريد أولاً');
    }
    await TenantStore(_db, () => user.uid).enrollConsumer(
        uid: user.uid,
        phone: phone,
        name: name,
        generatorId: gid,
        idNumber: idNumber.isEmpty ? null : idNumber,
        email: user.email!);
    await _loadAndCheckProfile(user.uid);
  }

  Future<void> updateProfile(
      {String? name, String? address, String? phone, String? idNumber}) async {
    final uid = state.user?.uid;
    if (uid == null) return;
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (address != null) data['address'] = address;
    final issue=contactError(phone??state.profile?.phone??'',idNumber??state.profile?.idNumber??'');
    if(issue!=null)throw CredentialFailure(issue);
    if (phone != null) data['phone'] = normalizeMobile(phone);
    if(idNumber!=null)data['idNumber']=normalizeDigits(idNumber).trim();
    if (data.isNotEmpty) {
      await _db.collection('users').doc(uid).update(data);
    }
  }

  Future<void> signOut() async {
    _profileSub?.cancel();
    await _auth.signOut();
    state = const AuthState(loading: false, startupResolved: true);
  }

  Future<void> reloadProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) await _loadAndCheckProfile(uid);
  }

  void clearError() => state = state.copyWith(error: null);

  @override
  void dispose() {
    _startupTimer?.cancel();
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
