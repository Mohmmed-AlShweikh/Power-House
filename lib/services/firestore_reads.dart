import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/tenant_provider.dart';
import '../models/user_model.dart';

/// Only transient listener failures are retried, twice per subscription lifetime.
/// Errors stay loading during backoff; an error/retry UI appears only at exhaustion.
Stream<T> retryFirestore<T>(Stream<T> Function() open,
    {List<Duration> backoff = const [
      Duration(milliseconds: 200),
      Duration(milliseconds: 500)
    ]}) {
  late StreamController<T> controller;
  StreamSubscription<T>? subscription;
  Timer? timer;
  var attempts = 0;
  var cancelled = false;
  void start() {
    if (cancelled) return;
    void fail(Object error, StackTrace stack) {
      if (cancelled) return;
      final retryable = error is FirebaseException &&
          ['permission-denied', 'unavailable'].contains(error.code);
      if (retryable && attempts < backoff.length) {
        final delay = backoff[attempts++];
        unawaited(subscription?.cancel());
        timer = Timer(delay, () {
          timer = null;
          start();
        });
      } else {
        controller.addError(error, stack);
        unawaited(controller.close());
      }
    }

    try {
      subscription = open().listen(controller.add, onError: fail, onDone: () {
        if (timer == null && !controller.isClosed) {
          unawaited(controller.close());
        }
      });
    } catch (error, stack) {
      fail(error, stack);
    }
  }

  controller = StreamController<T>(
      onListen: start,
      onCancel: () async {
        cancelled = true;
        timer?.cancel();
        await subscription?.cancel();
      });
  return controller.stream;
}

bool firestoreReady(Ref ref,
    {bool profileRequired = true, bool operational = false}) {
  final state = ref.watch(authProvider.select((s) => (
        uid: s.user?.uid,
        verified: !s.needsEmailVerification,
        resolved: s.startupResolved,
        hasProfile: s.profile != null,
        role: s.profile?.role,
        status: s.profile?.approvalStatus,
        subscription: s.profile?.subscriptionStatus,
        gid: s.profile?.generatorId
      )));
  if (!state.verified ||
      state.uid == null ||
      !state.resolved ||
      (profileRequired && !state.hasProfile)) {
    return false;
  }
  if (!operational || state.role == UserRole.superAdmin) return true;
  if (!state.hasProfile ||
      state.status != ApprovalStatus.approved ||
      (state.role == UserRole.consumer &&
          state.subscription != SubscriptionStatus.active)) {
    return false;
  }
  final access = ref.watch(tenantAccessProvider);
  return access != null &&
      !access.hasError &&
      !access.isLoading &&
      access.valueOrNull?.available == true;
}

extension ReadyQuery on Query<Map<String, dynamic>> {
  Stream<QuerySnapshot<Map<String, dynamic>>> autoSnapshots(Ref ref,
          {bool profileRequired = true}) =>
      firestoreReady(ref,
              profileRequired: profileRequired, operational: profileRequired)
          ? retryFirestore(() => snapshots())
          : const Stream.empty();
}

extension ReadyDocument on DocumentReference<Map<String, dynamic>> {
  Stream<DocumentSnapshot<Map<String, dynamic>>> autoSnapshots(Ref ref) =>
      firestoreReady(ref, operational: true)
          ? retryFirestore(() => snapshots())
          : const Stream.empty();
}
