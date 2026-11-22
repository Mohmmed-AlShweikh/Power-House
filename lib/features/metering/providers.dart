import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tenant_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_reads.dart';
import 'repository.dart';
import 'models.dart';

final meteringRepositoryProvider =
    Provider((ref) => MeteringRepository(ref.watch(tenantStoreProvider)));
final meterStaffProvider = StreamProvider((ref) => ref
    .watch(firestoreProvider)
    .collection('meterStaff')
    .where('generatorId', isEqualTo: ref.watch(tenantIdProvider))
    .autoSnapshots(ref));
final meterInvitesProvider = StreamProvider((ref) => ref
    .watch(firestoreProvider)
    .collection('meterInvites')
    .where('generatorId', isEqualTo: ref.watch(tenantIdProvider))
    .autoSnapshots(ref));
final readerOpenRoundProvider = StreamProvider((ref) => ref
    .watch(firestoreProvider)
    .collection('readerRounds')
    .doc(ref.watch(tenantIdProvider))
    .autoSnapshots(ref));
final meterAssignmentsProvider = StreamProvider<List<MeterAssignment>>((ref) {
  final uid = ref.watch(authProvider).user?.uid ?? '';
  final round = ref.watch(readerOpenRoundProvider).valueOrNull?.data();
  if (round == null || round['status'] != 'open') return Stream.value([]);
  return ref
      .watch(firestoreProvider)
      .collection('meterAssignments')
      .where('roundId', isEqualTo: round['roundId'])
      .where('readerUid', isEqualTo: uid)
      .where('generatorId', isEqualTo: ref.watch(tenantIdProvider))
      .autoSnapshots(ref)
      .map((s) =>
          s.docs.map((d) => MeterAssignment.fromMap(d.id, d.data())).toList());
});
final meterReadingProvider =
    StreamProvider.family<MeterReading?, String>((ref, id) {
  if (!firestoreReady(ref, operational: true)) {
    return const Stream.empty();
  }
  return retryFirestore(() => ref
          .watch(firestoreProvider)
          .collection('meterReadings')
          .doc(id)
          .snapshots(includeMetadataChanges: true))
      .map((d) => d.exists
          ? MeterReading(d.id, d.data()!, pending: d.metadata.hasPendingWrites)
          : null);
});
