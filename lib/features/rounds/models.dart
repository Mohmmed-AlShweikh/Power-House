import '../billing_settings/models.dart';

class CycleBill {
  final String id;
  final Map<String, dynamic> data;
  CycleBill(this.id, this.data);
  int get amount => data['amountAgorot'] as int;
  int get paid => data['paidAgorot'] as int? ?? 0;
  int get outstanding => amount - paid;
  String get status => outstanding == 0
      ? 'مدفوعة'
      : paid > 0
          ? 'مدفوعة جزئياً'
          : 'غير مدفوعة';
  Map<String, dynamic> get snapshot =>
      Map<String, dynamic>.from(data['snapshot']);
}

class BillingSubscriber {
  final String id;
  final Map<String, dynamic> data;
  BillingSubscriber(this.id, this.data);
  String get name => data['name'];
  int get previousMilli => data['previousMilli'] as int;
}

int positiveMoney(String input) {
  final n = parseFixed(input, 2);
  if (n <= 0 || n > 1000000000000) throw const FormatException('مبلغ غير صالح');
  return n;
}
