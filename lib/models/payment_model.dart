const paymentMethods = {
  'cash': 'نقداً',
  'bank': 'تحويل بنكي',
  'wallet': 'محفظة إلكترونية',
  'other': 'طريقة أخرى'
};
int? parsePaymentMinor(String value) {
  final text = value.trim();
  if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(text)) return null;
  final parts = text.split('.');
  return int.parse(parts.first) * 100 +
      (parts.length == 2 ? int.parse(parts.last.padRight(2, '0')) : 0);
}

class PaymentRecord {
  final int amountMinor, date, submittedAt, version;
  final String reference, method;
  const PaymentRecord(
      {required this.amountMinor,
      required this.date,
      required this.reference,
      required this.method,
      this.submittedAt = 0,
      this.version = 0});
  factory PaymentRecord.fromMap(Map<String, dynamic> data) => PaymentRecord(
      amountMinor: (data['amountMinor'] as num?)?.toInt() ?? 0,
      date: (data['date'] as num?)?.toInt() ?? 0,
      reference: data['reference'] as String? ?? '',
      method: data['method'] as String? ?? '',
      submittedAt: (data['submittedAt'] as num?)?.toInt() ?? 0,
      version: (data['version'] as num?)?.toInt() ?? 0);
  Map<String, dynamic> toMap() => {
        'amountMinor': amountMinor,
        'date': date,
        'reference': reference,
        'method': method,
        'submittedAt': submittedAt,
        'version': version
      };
  String get amountText => (amountMinor / 100).toStringAsFixed(2);
  String get methodText => paymentMethods[method] ?? 'غير محددة';
}
