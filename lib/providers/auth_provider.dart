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
  final bool needsCredentialCompletion;
  final bool isDemo;
  final String? error;

  const AuthState({
    this.user,
    this.profile,
    this.loading = true,
    this.startupResolved = false,
    this.needsRegistration = false,
    this.needsCredentialCompletion = false,
    this.isDemo = false,
    this.error,
  });

  AuthState copyWith({
    Object? user = const _Sentinel(),
    Object? profile = const _Sentinel(),
    bool? loading,
    bool? startupResolved,
    bool? needsRegistration,
    bool? needsCredentialCompletion,
    bool? isDemo,
    Object? error = const _Sentinel(),
  }) =>
      AuthState(
        user: user is _Sentinel ? this.user : user as User?,
        profile: profile is _Sentinel ? this.profile : profile as UserProfile?,
        loading: loading ?? this.loading,
        startupResolved: startupResolved ?? this.startupResolved,
        needsRegistration: needsRegistration ?? this.needsRegistration,
        needsCredentialCompletion:
            needsCredentialCompletion ?? this.needsCredentialCompletion,
        isDemo: isDemo ?? this.isDemo,
        error: error is _Sentinel ? this.error : error as String?,
      );
}

class _Sentinel {
  const _Sentinel();
}

// ── Demo profiles ──────────────────────────────────────────────────────────────

final _now = DateTime.now();

final _demoConsumer = UserProfile(
  uid: 'demo-consumer',
  idNumber: '0000000000',
  name: 'محمد أحمد',
  address: 'رام الله، حي البيرة',
  role: UserRole.consumer,
  approvalStatus: ApprovalStatus.approved,
  subscriptionStatus: SubscriptionStatus.active,
  ampereLimit: 10,
  createdAt: _now,
);

final _demoAdmin = UserProfile(
  uid: 'demo-admin',
  idNumber: '9999999999',
  name: 'أبو أحمد',
  address: 'رام الله',
  role: UserRole.admin,
  approvalStatus: ApprovalStatus.approved,
  subscriptionStatus: SubscriptionStatus.active,
  ampereLimit: 0,
  createdAt: _now,
);

final _demoSuperAdmin = UserProfile(
  uid: 'demo-super-admin',
  idNumber: '1111111111',
  name: 'المشرف العام',
  address: '',
  role: UserRole.superAdmin,
  approvalStatus: ApprovalStatus.approved,
  subscriptionStatus: SubscriptionStatus.active,
  ampereLimit: 0,
  createdAt: _now,
);

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
            needsCredentialCompletion: false,
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
    void apply(DocumentSnapshot<Map<String, dynamic>> doc) {
      if (!mounted || _auth.currentUser?.uid != uid) return;
      if (!doc.exists) {
        state = state.copyWith(
            user: _auth.currentUser,
            profile: null,
            needsRegistration: true,
            loading: false);
        return;
      }
      state = state.copyWith(
          user: _auth.currentUser,
          profile: UserProfile.fromMap(uid, doc.data()!),
          needsCredentialCompletion: doc.data()!['role'] != 'super_admin' &&
              (doc.data()!['credentialVersion'] != 1 ||
                  !credentials.hasPassword ||
                  !credentials.hasPhone ||
                  doc.data()!['phone'] != credentials.phone ||
                  credentials.email !=
                      idEmail((doc.data()!['idNumber'] as String?) ?? '')),
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
  Future<String?> login(String idNumber, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await credentials.loginId(idNumber, password);
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

  // Passwords are only changed by the authenticated owner through Firebase Auth.
  Future<String?> adminResetPassword(String uid, String newPassword) async =>
      'يستعيد صاحب الحساب كلمة المرور عبر رمز الهاتف من شاشة الدخول';

  /// Returns null on success, Arabic error message on failure.
  Future<String?> register(
          {required String idNumber,
          required String name,
          required String address,
          required String password,
          required UserRole role}) async =>
      'يلزم التحقق من رقم الهاتف لإنشاء حساب جديد';

  Future<void> enrollOwner(String name, String sector) async {
    final user = _auth.currentUser;
    if (user == null || user.phoneNumber == null) {
      throw StateError('تحقق من الهاتف أولاً');
    }
    await TenantStore(_db, () => user.uid).enrollOwner(
        uid: user.uid,
        phone: user.phoneNumber!,
        name: name,
        sector: sector,
        idNumber: _enrollmentId());
    await _loadAndCheckProfile(user.uid);
  }

  Future<void> enrollConsumer(String name, String gid) async {
    final user = _auth.currentUser;
    if (user == null || user.phoneNumber == null) {
      throw StateError('تحقق من الهاتف أولاً');
    }
    await TenantStore(_db, () => user.uid).enrollConsumer(
        uid: user.uid,
        phone: user.phoneNumber!,
        name: name,
        generatorId: gid,
        idNumber: _enrollmentId());
    await _loadAndCheckProfile(user.uid);
  }

  String _enrollmentId() {
    final email = _auth.currentUser?.email ?? '';
    final id = email.split('@').first;
    if (!credentials.hasPassword ||
        !validNationalId(id) ||
        email != idEmail(id)) {
      throw const CredentialFailure('أكمل ربط الهوية وكلمة المرور أولاً');
    }
    return id;
  }

  Future<void> demoLogin(UserRole role) async {
    final profile = switch (role) {
      UserRole.superAdmin => _demoSuperAdmin,
      UserRole.admin => _demoAdmin,
      _ => _demoConsumer,
    };
    state = state.copyWith(
      isDemo: true,
      startupResolved: true,
      profile: profile,
      loading: false,
      error: null,
    );
  }

  Future<void> updateProfile(
      {String? name, String? address, String? phone}) async {
    if (state.isDemo) {
      final updated =
          state.profile!.copyWith(name: name, address: address, phone: phone);
      state = state.copyWith(profile: updated);
      return;
    }
    final uid = state.user?.uid;
    if (uid == null) return;
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (address != null) data['address'] = address;
    if (phone != null && phone != state.profile?.phone) {
      throw const CredentialFailure('غيّر الهاتف من إعدادات الدخول بعد التحقق');
    }
    if (data.isNotEmpty) {
      await _db.collection('users').doc(uid).update(data);
    }
  }

  Future<void> signOut() async {
    _profileSub?.cancel();
    if (!state.isDemo) await _auth.signOut();
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

final demoModeProvider =
    Provider<bool>((ref) => ref.watch(authProvider).isDemo);
