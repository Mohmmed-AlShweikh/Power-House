import 'dart:async';
import '../services/firestore_reads.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/generator_model.dart';
import '../models/user_model.dart';
import '../services/tenant_store.dart';
import 'auth_provider.dart';

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final tenantIdProvider = Provider<String>((ref) =>
    ref.watch(authProvider).profile?.generatorId ?? defaultGeneratorId);
final tenantStoreProvider = Provider<TenantStore>((ref) => TenantStore(
    ref.watch(firestoreProvider),
    () =>
        ref.read(authProvider).user?.uid ??
        FirebaseAuth.instance.currentUser?.uid));

Query<Map<String, dynamic>> scopedQuery(Ref ref, String collection,
        {String? userId}) =>
    tenantQuery(
        ref.watch(firestoreProvider), collection, ref.watch(tenantIdProvider),
        userId: userId,
        superAdmin:
            ref.watch(authProvider).profile?.role == UserRole.superAdmin);

final generatorDirectoryProvider = StreamProvider<List<GeneratorAccount>>(
    (ref) => ref
        .watch(firestoreProvider)
        .collection('generatorDirectory')
        .where('status', isEqualTo: 'approved')
        .where('subscriptionStatus', isEqualTo: 'active')
        .autoSnapshots(ref, profileRequired: false)
        .map((s) => s.docs
            .map((d) => GeneratorAccount.fromMap(d.id, d.data()))
            .toList()));
final generatorRequestsProvider = StreamProvider<List<GeneratorAccount>>(
    (ref) => ref
            .watch(firestoreProvider)
            .collection('generators')
            .autoSnapshots(ref)
            .map((s) {
          final list = s.docs
              .map((d) => GeneratorAccount.fromMap(d.id, d.data()))
              .toList();
          list.sort((a, b) => (a.status == GeneratorApproval.pending ? 0 : 1)
              .compareTo(b.status == GeneratorApproval.pending ? 0 : 1));
          return list;
        }));

Stream<Map<String, dynamic>> watchGenerator(FirebaseFirestore db, String gid) {
  late StreamController<Map<String, dynamic>> controller;
  StreamSubscription? generatorSub, legacySub;
  var exists = false;
  controller = StreamController(onListen: () {
    generatorSub =
        db.collection('generators').doc(gid).snapshots().listen((doc) {
      exists = doc.exists;
      if (exists) {
        controller.add(doc.data()!);
      } else if (gid == defaultGeneratorId) {
        legacySub ??= db
            .collection('system')
            .doc('generator')
            .snapshots()
            .listen((legacy) {
          if (!exists) {
            controller.add({
              ...?legacy.data(),
              'status': 'approved',
              'subscriptionStatus': 'active'
            });
          }
        }, onError: controller.addError);
      } else {
        controller.add({'status': 'pending', 'subscriptionStatus': 'inactive'});
      }
    }, onError: controller.addError);
  }, onCancel: () async {
    await generatorSub?.cancel();
    await legacySub?.cancel();
  });
  return controller.stream;
}

final currentGeneratorAccountProvider = StreamProvider<GeneratorAccount>((ref) {
  final gid = ref.watch(tenantIdProvider);
  final db = ref.watch(firestoreProvider);
  if (!firestoreReady(ref)) return const Stream.empty();
  return retryFirestore(() => watchGenerator(db, gid))
      .map((data) => GeneratorAccount.fromMap(gid, data));
});

final tenantAccessProvider = Provider<AsyncValue<GeneratorAccount>?>((ref) {
  final state = ref.watch(authProvider);
  if (state.isDemo ||
      state.profile == null ||
      state.profile!.role == UserRole.superAdmin) {
    return null;
  }
  return ref.watch(currentGeneratorAccountProvider);
});

// Private owner data is never added to the public generator directory.
final ownerNameProvider = StreamProvider.family<String, String>((ref, uid) =>
    ref
        .watch(firestoreProvider)
        .collection('users')
        .doc(uid)
        .autoSnapshots(ref)
        .map((doc) => (doc.data()?['name'] as String?) ?? 'غير متاح'));
