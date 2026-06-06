enum BillStatus { pending, pendingReview, paid, rejected }

class Bill {
  final String id;
  final String userId;
  final String month;
  final int year;
  final int? weekNumber;
  final int amount;
  final double kwh;
  final BillStatus status;
  final String? receiptBase64;
  final DateTime createdAt;

  const Bill({
    required this.id,
    required this.userId,
    required this.month,
    required this.year,
    this.weekNumber,
    required this.amount,
    required this.kwh,
    required this.status,
    this.receiptBase64,
    required this.createdAt,
  });

  factory Bill.fromMap(String id, Map<String, dynamic> map) {
    final weekValue = map['weekNumber'];
    return Bill(
      id: id,
      userId: map['userId'] ?? '',
      month: map['month'] ?? '',
      year: map['year'] ?? 2024,
      weekNumber: weekValue is int
          ? weekValue
          : (weekValue is num ? weekValue.toInt() : null),
      amount: map['amount'] ?? 0,
      kwh: (map['kwh'] ?? 0).toDouble(),
      status: _parseStatus(map['status']),
      receiptBase64: map['receiptBase64'],
      createdAt: _parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    final data = {
      'userId': userId,
      'month': month,
      'year': year,
      'amount': amount,
      'kwh': kwh,
      'status': status.name,
      'receiptBase64': receiptBase64,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
    if (weekNumber != null) {
      data['weekNumber'] = weekNumber;
      data['billingPeriod'] = 'weekly';
    } else {
      data['billingPeriod'] = 'monthly';
    }
    return data;
  }

  static BillStatus _parseStatus(dynamic v) {
    if (v == 'paid') return BillStatus.paid;
    if (v == 'rejected') return BillStatus.rejected;
    if (v == 'pendingReview') return BillStatus.pendingReview;
    return BillStatus.pending;
  }

  static DateTime _parseDate(dynamic v) {
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return DateTime.now();
  }
}
