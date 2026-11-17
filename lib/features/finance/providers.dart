import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tenant_provider.dart';
import '../../services/firestore_reads.dart';
import 'models.dart';
import 'repository.dart';

final financeRepositoryProvider =
    Provider((ref) => FinanceRepository(ref.watch(tenantStoreProvider)));
final financeControlProvider = StreamProvider((ref) => ref
    .watch(firestoreProvider)
    .collection('financeControl')
    .doc(ref.watch(tenantIdProvider))
    .autoSnapshots(ref));
typedef FinancePeriod = ({String kind, String key, String end});
final financeTotalsProvider =
    StreamProvider.family<FinanceTotals, FinancePeriod>((ref, p) {
  final c = ref.watch(financeControlProvider).valueOrNull?.data();
  if (c == null) return Stream.value(const FinanceTotals());
  final gid = ref.watch(tenantIdProvider), gen = c['generation'];
  final collection =
      ref.watch(firestoreProvider).collection('financeSummaries');
  if (p.kind == 'day') {
    return collection
        .where('generatorId', isEqualTo: gid)
        .where('generation', isEqualTo: gen)
        .where('kind', isEqualTo: 'day')
        .where('key', isGreaterThanOrEqualTo: p.key)
        .where('key', isLessThanOrEqualTo: p.end)
        .autoSnapshots(ref)
        .map((s) => s.docs.fold(const FinanceTotals(),
            (a, b) => a + FinanceTotals.fromMap(b.data())));
  }
  return collection
      .doc('${gid}_${gen}_${p.kind}_${p.key}')
      .autoSnapshots(ref)
      .map((s) => FinanceTotals.fromMap(s.data() ?? {}));
});
final expensesProvider = StreamProvider.family((ref, FinancePeriod p) {
  var q = ref
      .watch(firestoreProvider)
      .collection('expenses')
      .where('generatorId', isEqualTo: ref.watch(tenantIdProvider))
      .where('deleted', isEqualTo: false);
  if (p.kind == 'round') {
    q = q.where('roundId', isEqualTo: p.key);
  } else {
    final start =
        DateTime.parse('${p.key}${p.kind == 'month' ? '-01' : ''}T00:00:00Z');
    final end = p.kind == 'month'
        ? DateTime.utc(start.year, start.month + 1)
        : DateTime.parse('${p.end}T00:00:00Z').add(const Duration(days: 1));
    q = q
        .where('date', isGreaterThanOrEqualTo: start.millisecondsSinceEpoch)
        .where('date', isLessThan: end.millisecondsSinceEpoch);
  }
  return q.limit(200).autoSnapshots(ref);
});
