const defaultGeneratorId = 'default';

String normalizedGeneratorId(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : defaultGeneratorId;

enum GeneratorApproval { pending, approved, rejected, suspended }

class GeneratorAccount {
  final String id, name, sector, ownerUid, subscriptionStatus, rejectionReason;
  final GeneratorApproval status;
  const GeneratorAccount(
      {required this.id,
      required this.name,
      required this.sector,
      this.ownerUid = '',
      this.subscriptionStatus = 'active',
      this.rejectionReason = '',
      this.status = GeneratorApproval.pending});
  factory GeneratorAccount.fromMap(String id, Map<String, dynamic> data) =>
      GeneratorAccount(
          id: id,
          name: data['name'] as String? ?? '',
          sector: data['sector'] as String? ?? '',
          ownerUid: data['ownerUid'] as String? ?? '',
          subscriptionStatus:
              data['subscriptionStatus'] as String? ?? 'inactive',
          rejectionReason: data['rejectionReason'] as String? ?? '',
          status: GeneratorApproval.values.firstWhere(
              (s) => s.name == data['status'],
              orElse: () => GeneratorApproval.pending));
  bool get available =>
      status == GeneratorApproval.approved && subscriptionStatus == 'active';
  Map<String, dynamic> directory() => {
        'name': name,
        'sector': sector,
        'status': status.name,
        'subscriptionStatus': subscriptionStatus
      };
}
