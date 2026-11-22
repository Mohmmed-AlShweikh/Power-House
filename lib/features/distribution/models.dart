import '../billing_settings/models.dart';

class PublishResult {
  final int sent, skipped, failed, notified;
  const PublishResult(this.sent, this.skipped, this.failed, this.notified);
}

String billShareText(Map<String, dynamic> b) =>
    'بوابة المولدات\nفاتورة ${DateTime.fromMillisecondsSinceEpoch(b['date'], isUtc: true).toIso8601String().substring(0, 10)}\nالمشترك: ${b['name']}\nالمبلغ: \u2066₪${formatFixed(b['amountAgorot'], 2)}\u2069\nالمدفوع: \u2066₪${formatFixed(b['paidAgorot'], 2)}\u2069\nالمتبقي: \u2066₪${formatFixed(b['amountAgorot'] - b['paidAgorot'], 2)}\u2069\nيرجى مراجعة صاحب المولد عند وجود استفسار.';
