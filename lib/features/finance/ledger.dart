import 'package:cloud_firestore/cloud_firestore.dart';

String utcDay(int date) =>
    DateTime.fromMillisecondsSinceEpoch(date, isUtc: true)
        .toIso8601String()
        .substring(0, 10);

class LedgerContext {
  final String generatorId, generation;
  LedgerContext(this.generatorId, this.generation);
}

Future<LedgerContext> readLedger(
    Transaction tx, FirebaseFirestore db, String gid) async {
  final c = await tx.get(db.collection('financeControl').doc(gid));
  if (c.data()?['locked'] == true) {
    throw StateError('إعادة حساب الملخصات جارية؛ حاول بعد اكتمالها');
  }
  return LedgerContext(gid, c.data()?['generation'] ?? 'initial');
}

/// Every entry is a delta attached to its economic date and originating round.
Map<String, Map<String, dynamic>> ledgerDeltas(
    String gid, String gen, List<Map<String, dynamic>> entries) {
  final grouped = <String, Map<String, dynamic>>{};
  for (final e in entries) {
    final day = utcDay(e['date']);
    for (final pair in [
      ('total', 'all'),
      ('month', day.substring(0, 7)),
      ('day', day),
      ('round', e['roundId'] as String)
    ]) {
      final id = '${gid}_${gen}_${pair.$1}_${pair.$2}';
      final out = grouped.putIfAbsent(
          id,
          () => {
                'generatorId': gid,
                'generation': gen,
                'kind': pair.$1,
                'key': pair.$2
              });
      for (final f in [
        'billedAgorot',
        'collectedAgorot',
        'outstandingAgorot',
        'costAgorot',
        'fuelAgorot',
        'maintenanceAgorot',
        'wagesAgorot',
        'equipmentAgorot',
        'otherAgorot'
      ]) {
        out[f] = (out[f] as int? ?? 0) + (e[f] as int? ?? 0);
      }
    }
  }
  return grouped;
}

Future<void> applyLedger(Transaction tx, FirebaseFirestore db, LedgerContext c,
    List<Map<String, dynamic>> entries) async {
  final deltas = ledgerDeltas(c.generatorId, c.generation, entries);
  final before = <String, Map<String, dynamic>>{};
  for (final id in deltas.keys) {
    before[id] =
        (await tx.get(db.collection('financeSummaries').doc(id))).data() ?? {};
  }
  for (final e in deltas.entries) {
    tx.set(db.collection('financeSummaries').doc(e.key), {
      for (final v in e.value.entries)
        v.key: v.value is int
            ? (before[e.key]![v.key] as int? ?? 0) + (v.value as int)
            : v.value
    });
  }
}
