class MeterAssignment {
  final String id, generatorId, readerUid, roundId, name, address, number;
  final int previousMilli, averageMilli;
  const MeterAssignment(
      {required this.id,
      required this.generatorId,
      required this.readerUid,
      required this.roundId,
      required this.name,
      required this.address,
      required this.number,
      required this.previousMilli,
      this.averageMilli = 0});
  factory MeterAssignment.fromMap(String id, Map<String, dynamic> d) =>
      MeterAssignment(
          id: id,
          generatorId: d['generatorId'],
          readerUid: d['readerUid'],
          roundId: d['roundId'],
          name: d['name'],
          address: d['address'],
          number: d['number'],
          previousMilli: d['previousMilli'],
          averageMilli: d['averageMilli'] ?? 0);
  Map<String, dynamic> toMap() => {
        'generatorId': generatorId,
        'readerUid': readerUid,
        'roundId': roundId,
        'name': name,
        'address': address,
        'number': number,
        'previousMilli': previousMilli,
        'averageMilli': averageMilli
      };
  bool abnormal(int current) =>
      averageMilli > 0 && current - previousMilli > averageMilli * 3;
}

class MeterReading {
  final String id;
  final Map<String, dynamic> data;
  final bool pending;
  MeterReading(this.id, this.data, {this.pending = false});
  int get currentMilli => data['currentMilli'] as int;
}
