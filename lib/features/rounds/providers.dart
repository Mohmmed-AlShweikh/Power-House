import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../services/firestore_reads.dart';
import '../../models/user_model.dart';
import 'repository.dart';

final roundsRepositoryProvider =
    Provider((ref) => RoundsRepository(ref.watch(tenantStoreProvider)));
final billingSubscribersProvider = StreamProvider((ref) => ref
    .watch(firestoreProvider)
    .collection('billingSubscribers')
    .where('generatorId', isEqualTo: ref.watch(tenantIdProvider))
    .autoSnapshots(ref));
final billingRoundsProvider = StreamProvider((ref) => ref
    .watch(firestoreProvider)
    .collection('billingRounds')
    .where('generatorId', isEqualTo: ref.watch(tenantIdProvider))
    .autoSnapshots(ref));
final roundAssignmentsProvider = StreamProvider.family((ref, String rid) => ref
    .watch(firestoreProvider)
    .collection('meterAssignments')
    .where('generatorId', isEqualTo: ref.watch(tenantIdProvider))
    .where('roundId', isEqualTo: rid)
    .autoSnapshots(ref));
final roundReadingsProvider = StreamProvider.family((ref, String rid) => ref
    .watch(firestoreProvider)
    .collection('meterReadings')
    .where('generatorId', isEqualTo: ref.watch(tenantIdProvider))
    .where('roundId', isEqualTo: rid)
    .autoSnapshots(ref));
final cycleBillsProvider = StreamProvider((ref) {
  var q = ref
      .watch(firestoreProvider)
      .collection('cycleBills')
      .where('generatorId', isEqualTo: ref.watch(tenantIdProvider));
  if (ref.watch(authProvider).profile?.role == UserRole.consumer) {
    q = q
        .where('userId', isEqualTo: ref.watch(authProvider).user?.uid ?? '')
        .where('published', isEqualTo: true);
  }
  return q.autoSnapshots(ref);
});
final cyclePaymentsProvider = StreamProvider((ref) {
  var q = ref
      .watch(firestoreProvider)
      .collection('cyclePayments')
      .where('generatorId', isEqualTo: ref.watch(tenantIdProvider));
  if (ref.watch(authProvider).profile?.role == UserRole.consumer) {
    q = q.where('userId', isEqualTo: ref.watch(authProvider).user?.uid ?? '');
  }
  return q.autoSnapshots(ref);
});
final accountBalancesProvider = StreamProvider((ref) {
  var q = ref
      .watch(firestoreProvider)
      .collection('accountBalances')
      .where('generatorId', isEqualTo: ref.watch(tenantIdProvider));
  if (ref.watch(authProvider).profile?.role == UserRole.consumer) {
    q = q.where('userId', isEqualTo: ref.watch(authProvider).user?.uid ?? '');
  }
  return q.autoSnapshots(ref);
});
