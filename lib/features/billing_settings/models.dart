/// Decimal user input is converted once, without binary floating-point money.
int parseFixed(String input, int digits) {
  final match = RegExp(r'^(\d{1,9})(?:\.(\d+))?$').firstMatch(input.trim());
  if (match == null || (match[2]?.length ?? 0) > digits) {
    throw const FormatException('أدخل رقماً موجباً بالدقة المطلوبة');
  }
  final scale = _power(digits);
  return int.parse(match[1]!) * scale +
      int.parse((match[2] ?? '').padRight(digits, '0'));
}

int _power(int n) {
  var result = 1;
  for (var i = 0; i < n; i++) {
    result *= 10;
  }
  return result;
}

String formatFixed(int n, int digits) =>
    '${n ~/ _power(digits)}.${(n % _power(digits)).toString().padLeft(digits, '0')}';

class BillingSettings {
  final int priceAgorot, minimumUnitsMilli, cycleDays, roundingThresholdAgorot;
  final String unitName;
  const BillingSettings(
      {this.priceAgorot = 200,
      this.minimumUnitsMilli = 0,
      this.cycleDays = 10,
      this.roundingThresholdAgorot = 50,
      this.unitName = 'وحدة'});
  void validate() {
    if (priceAgorot <= 0 ||
        priceAgorot > 1000000 ||
        minimumUnitsMilli < 0 ||
        minimumUnitsMilli > 1000000000 ||
        cycleDays < 1 ||
        cycleDays > 366 ||
        roundingThresholdAgorot < 1 ||
        roundingThresholdAgorot > 99 ||
        unitName.trim().isEmpty ||
        unitName.length > 24) {
      throw const FormatException(
          'تحقق من السعر والحد الأدنى ودورة الفوترة والتقريب (1–99)');
    }
  }

  factory BillingSettings.fromMap(Map<String, dynamic> d) => BillingSettings(
      priceAgorot: d['priceAgorot'] as int? ?? 200,
      minimumUnitsMilli: d['minimumUnitsMilli'] as int? ?? 0,
      cycleDays: d['cycleDays'] as int? ?? 10,
      roundingThresholdAgorot: d['roundingThresholdAgorot'] as int? ?? 50,
      unitName: d['unitName'] as String? ?? 'وحدة');
  Map<String, dynamic> toMap() => {
        'priceAgorot': priceAgorot,
        'minimumUnitsMilli': minimumUnitsMilli,
        'cycleDays': cycleDays,
        'roundingThresholdAgorot': roundingThresholdAgorot,
        'unitName': unitName
      };
}

/// Frozen invoice calculation. Numerators are integer thousandths of an agora.
/// No later settings read is needed to display or verify an old invoice.
class BillingCalculation {
  final int previousMilli,
      currentMilli,
      differenceMilli,
      rawNumerator,
      minimumNumerator,
      amountAgorot;
  final bool minimumApplied, newMeter;
  final int? startingMilli;
  final BillingSettings settings;
  const BillingCalculation(
      {required this.previousMilli,
      required this.currentMilli,
      required this.differenceMilli,
      required this.rawNumerator,
      required this.minimumNumerator,
      required this.amountAgorot,
      required this.minimumApplied,
      required this.settings,
      required this.newMeter,
      this.startingMilli});
  Map<String, dynamic> toMap() => {
        'previousMilli': previousMilli,
        'currentMilli': currentMilli,
        'differenceMilli': differenceMilli,
        'rawNumerator': rawNumerator,
        'minimumNumerator': minimumNumerator,
        'denominator': 1000,
        'amountAgorot': amountAgorot,
        'minimumApplied': minimumApplied,
        'newMeter': newMeter,
        if (startingMilli != null) 'startingMilli': startingMilli,
        'settings': settings.toMap()
      };
}

BillingCalculation calculateBill(
    {required int previousMilli,
    required int currentMilli,
    required BillingSettings settings,
    bool newMeter = false,
    int? startingMilli}) {
  settings.validate();
  final start = newMeter ? startingMilli : previousMilli;
  if (previousMilli < 0 ||
      currentMilli < 0 ||
      start == null ||
      start < 0 ||
      currentMilli < start ||
      currentMilli > 1000000000 ||
      previousMilli > 1000000000) {
    throw const FormatException(
        'القراءة الحالية أقل من السابقة؛ تغيير العداد يحتاج قيمة بداية واضحة');
  }
  final difference = currentMilli - start;
  final raw = difference * settings.priceAgorot;
  final minimum = settings.minimumUnitsMilli * settings.priceAgorot;
  final effective = raw < minimum ? minimum : raw;
  final whole = effective ~/ 100000;
  final remainder = effective % 100000;
  final rounded =
      (whole + (remainder >= settings.roundingThresholdAgorot * 1000 ? 1 : 0)) *
          100;
  return BillingCalculation(
      previousMilli: previousMilli,
      currentMilli: currentMilli,
      differenceMilli: difference,
      rawNumerator: raw,
      minimumNumerator: minimum,
      amountAgorot: rounded,
      minimumApplied: raw < minimum,
      settings: settings,
      newMeter: newMeter,
      startingMilli: newMeter ? startingMilli : null);
}
