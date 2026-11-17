import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tenant_provider.dart';
import '../../services/firestore_reads.dart';
import 'repository.dart';

final distributionRepositoryProvider =
    Provider((ref) => DistributionRepository(ref.watch(tenantStoreProvider)));
final shareBillsProvider = StreamProvider.family((ref, String rid) => ref
    .watch(firestoreProvider)
    .collection('cycleBills')
    .where('generatorId', isEqualTo: ref.watch(tenantIdProvider))
    .where('roundId', isEqualTo: rid)
    .autoSnapshots(ref));
final billSharesProvider = StreamProvider.family((ref, String rid) => ref
    .watch(firestoreProvider)
    .collection('billShares')
    .where('roundId', isEqualTo: rid)
    .where('generatorId', isEqualTo: ref.watch(tenantIdProvider))
    .autoSnapshots(ref));
