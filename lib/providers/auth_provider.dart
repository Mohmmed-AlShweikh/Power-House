import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';
import '../services/firebase_service.dart';

class AuthState {
  final User? user;
  final UserProfile? profile;
  final bool loading;
  final bool isDemo;
  final String? error;

  const AuthState({
    this.user,
    this.profile,
    this.loading = true,
    this.isDemo = false,
    this.error,
  });

  AuthState copyWith({
    User? user,
    UserProfile? profile,
    bool? loading,
    bool? isDemo,
    Object? error = const _Sentinel(),
  }) =>
      AuthState(
        user: user ?? this.user,
        profile: profile ?? this.profile,
        loading: loading ?? this.loading,
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
  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  StreamSubscription? _authSub;
  StreamSubscription? _profileSub;
  bool _seeding = false;

  static String _toEmail(String id) =>
      '${id.trim()}@powershare.app';

  static const _superAdminId = '1234567890';
  static const _superAdminPass = 'Admin@2024!';

  void _init() async {
    // Timeout safety net
    Future.delayed(const Duration(seconds: 8), () {
      if (state.loading) state = state.copyWith(loading: false);
    });

    // Seed super admin account then start listener
    _seeding = true;
    await _seedSuperAdmin();
    _seeding = false;

    _authSub = _auth.authStateChanges().listen((u) async {
      if (_seeding) return;
      if (u == null) {
        state = state.copyWith(
            user: null,
            profile: null,
            loading: false,
            error: const _Sentinel());
        return;
      }
      state = state.copyWith(user: u, loading: true);
      await _loadAndCheckProfile(u.uid);
    }, onError: (_) {
      state = state.copyWith(loading: false);
    });
  }

  Future<void> _seedSuperAdmin() async {
    try {
      // Check if already in Firestore
      final q = await _db
          .collection('users')
          .where('role', isEqualTo: 'super_admin')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 4));

      if (q.docs.isNotEmpty) return; // already seeded

      // Try to create the Firebase Auth account
      try {
        final cred = await _auth.createUserWithEmailAndPassword(
          email: _toEmail(_superAdminId),
          password: _superAdminPass,
        );
        await _db.collection('users').doc(cred.user!.uid).set({
          'idNumber': _superAdminId,
          'name': 'المشرف العام',
          'address': '',
          'role': 'super_admin',
          'status': 'approved',
          'subscriptionStatus': 'active',
          'ampereLimit': 0,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
        await _auth.signOut();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // Auth exists but Firestore doc missing — sign in, fix, sign out
          try {
            final c = await _auth.signInWithEmailAndPassword(
              email: _toEmail(_superAdminId),
              password: _superAdminPass,
            );
            await _db.collection('users').doc(c.user!.uid).set({
              'idNumber': _superAdminId,
              'name': 'المشرف العام',
              'address': '',
              'role': 'super_admin',
              'status': 'approved',
              'subscriptionStatus': 'active',
              'ampereLimit': 0,
              'createdAt': DateTime.now().millisecondsSinceEpoch,
            }, SetOptions(merge: true));
            await _auth.signOut();
          } catch (_) {}
        }
      }
    } catch (_) {
      // Network or permissions issue — continue without seed
    }
  }

  Future<void> _loadAndCheckProfile(String uid) async {
    _profileSub?.cancel();
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) {
        await _auth.signOut();
        state = state.copyWith(
            user: null, profile: null, loading: false,
            error: 'الحساب غير موجود في النظام. تواصل مع المشرف.');
        return;
      }
      final p = UserProfile.fromMap(uid, doc.data()!);
      switch (p.approvalStatus) {
        case ApprovalStatus.pending:
          await _auth.signOut();
          final msg = p.role == UserRole.admin
              ? 'طلبك قيد المراجعة من قِبل المشرف العام.'
              : 'طلبك قيد المراجعة من قِبل صاحب المولد.';
          state = state.copyWith(
              user: null, profile: null, loading: false, error: msg);
          break;
        case ApprovalStatus.rejected:
          await _auth.signOut();
          state = state.copyWith(
              user: null,
              profile: null,
              loading: false,
              error: 'تم رفض طلبك من قِبل المشرف. تواصل معه للمزيد.');
          break;
        case ApprovalStatus.approved:
          state = state.copyWith(profile: p, loading: false);
          _profileSub =
              _db.collection('users').doc(uid).snapshots().listen((s) {
            if (s.exists) {
              state = state.copyWith(
                  profile: UserProfile.fromMap(uid, s.data()!));
            }
          });
          break;
      }
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  // ── Public Methods ──────────────────────────────────────────────────────────

  /// Returns null on success, Arabic error message on failure.
  Future<String?> login(String idNumber, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _auth.signInWithEmailAndPassword(
        email: _toEmail(idNumber),
        password: password,
      );
      // _loadAndCheckProfile is triggered by the auth listener
      return null;
    } on FirebaseAuthException catch (e) {
      final msg = _friendlyError(e.code);
      state = state.copyWith(loading: false, error: msg);
      return msg;
    } catch (_) {
      const msg = 'تعذّر الاتصال بالخادم. تحقق من اتصالك.';
      state = state.copyWith(loading: false, error: msg);
      return msg;
    }
  }

  /// Admin resets a user's password and sends them a notification.
  Future<String?> adminResetPassword(String uid, String newPassword) async {
    try {
      await _db.collection('users').doc(uid).update({
        'password': newPassword,
        'passwordUpdatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      NotificationService().notifyPasswordReset(uid);
      return null;
    } catch (_) {
      return 'تعذّر تحديث كلمة المرور. حاول مجدداً.';
    }
  }

  /// Returns null on success, Arabic error message on failure.
  Future<String?> register({
    required String idNumber,
    required String name,
    required String address,
    required String password,
    required UserRole role,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _toEmail(idNumber),
        password: password,
      );
      final uid = cred.user!.uid;
      final firestoreRole =
          role == UserRole.admin ? 'generator_owner' : 'user';
      await _db.collection('users').doc(uid).set({
        'idNumber': idNumber,
        'name': name,
        'address': address,
        'role': firestoreRole,
        'status': 'pending',
        'subscriptionStatus': 'inactive',
        'ampereLimit': 0,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      await _auth.signOut();
      // Send registration notification
      if (role == UserRole.admin) {
        NotificationService().notifySuperAdminNewOwner();
      } else {
        NotificationService().notifyAllAdminsNewConsumer();
      }
      state = state.copyWith(loading: false, error: null);
      return null;
    } on FirebaseAuthException catch (e) {
      final msg = _friendlyError(e.code);
      state = state.copyWith(loading: false, error: msg);
      return msg;
    } catch (_) {
      const msg = 'تعذّر إنشاء الحساب. حاول مجدداً.';
      state = state.copyWith(loading: false, error: msg);
      return msg;
    }
  }

  void demoLogin(UserRole role) {
    final profile = switch (role) {
      UserRole.superAdmin => _demoSuperAdmin,
      UserRole.admin => _demoAdmin,
      _ => _demoConsumer,
    };
    state = state.copyWith(
      isDemo: true,
      profile: profile,
      loading: false,
      error: null,
    );
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
    if (data.isNotEmpty) {
      await _db.collection('users').doc(uid).update(data);
    }
  }

  Future<void> signOut() async {
    _profileSub?.cancel();
    if (!state.isDemo) await _auth.signOut();
    state = const AuthState(loading: false);
  }

  void clearError() => state = state.copyWith(error: null);

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }

  static String _friendlyError(String? code) {
    switch (code) {
      case 'user-not-found':
      case 'invalid-credential':
      case 'wrong-password':
        return 'رقم الهوية أو كلمة المرور غير صحيحة.';
      case 'email-already-in-use':
        return 'رقم الهوية هذا مسجّل بالفعل. جرّب تسجيل الدخول.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة. استخدم 8 أحرف أو أكثر.';
      case 'too-many-requests':
        return 'عدد كبير من المحاولات. انتظر قليلاً وحاول مجدداً.';
      case 'network-request-failed':
        return 'تعذّر الاتصال بالإنترنت. تحقق من اتصالك.';
      case 'operation-not-allowed':
        return 'تسجيل الدخول بالبريد الإلكتروني غير مفعّل في Firebase Console.';
      default:
        return 'حدث خطأ (${code ?? 'unknown'}). حاول مجدداً.';
    }
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

final demoModeProvider =
    Provider<bool>((ref) => ref.watch(authProvider).isDemo);
