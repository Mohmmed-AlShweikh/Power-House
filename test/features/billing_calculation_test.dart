import 'package:flutter_test/flutter_test.dart';
import 'package:generator_portal/features/billing_settings/models.dart';

void main() {
  test('decimal parsing never accepts excess precision, signs or exponents',
      () {
    expect(parseFixed('38.50', 2), 3850);
    for (final v in ['1.001', '-1', '1e2', 'NaN']) {
      expect(() => parseFixed(v, 2), throwsFormatException);
    }
  });
  test('normal reading snapshot 20 to 30 at 28 shekels', () {
    final c = calculateBill(
        previousMilli: 20000,
        currentMilli: 30000,
        settings: const BillingSettings(priceAgorot: 2800));
    expect(c.amountAgorot, 28000);
    expect(c.rawNumerator, 28000000);
    expect(c.minimumApplied, false);
  });
  test('minimum applies before rounding, including zero consumption', () {
    final c = calculateBill(
        previousMilli: 20000,
        currentMilli: 20000,
        settings:
            const BillingSettings(priceAgorot: 2800, minimumUnitsMilli: 1500));
    expect(c.amountAgorot, 4200);
    expect(c.minimumApplied, true);
  });
  for (final r in [0, 49, 50, 99]) {
    test('rounding boundary $r agorot', () {
      final c = calculateBill(
          previousMilli: 0,
          currentMilli: 1000,
          settings: BillingSettings(priceAgorot: 3800 + r));
      expect(c.amountAgorot, r < 50 ? 3800 : 3900);
    });
  }
  test('fractional unit raw numerator remains exact through rounding', () {
    final c = calculateBill(
        previousMilli: 0,
        currentMilli: 1499,
        settings: const BillingSettings(priceAgorot: 100));
    expect(c.rawNumerator, 149900);
    expect(c.amountAgorot, 100);
  });
  test('owner threshold configurable', () {
    expect(
        calculateBill(
                previousMilli: 0,
                currentMilli: 1000,
                settings: const BillingSettings(
                    priceAgorot: 3840, roundingThresholdAgorot: 40))
            .amountAgorot,
        3900);
  });
  test('new meter requires explicit start; ordinary decreasing reading blocked',
      () {
    expect(
        () => calculateBill(
            previousMilli: 5000,
            currentMilli: 1000,
            settings: const BillingSettings()),
        throwsFormatException);
    expect(
        () => calculateBill(
            previousMilli: 5000,
            currentMilli: 1000,
            newMeter: true,
            settings: const BillingSettings()),
        throwsFormatException);
    expect(
        calculateBill(
                previousMilli: 5000,
                currentMilli: 1000,
                newMeter: true,
                startingMilli: 500,
                settings: const BillingSettings())
            .differenceMilli,
        500);
  });
  test('later price change leaves frozen original snapshot unchanged', () {
    final c = calculateBill(
        previousMilli: 0,
        currentMilli: 1000,
        settings: const BillingSettings(priceAgorot: 200));
    final old = c.toMap();
    calculateBill(
        previousMilli: 0,
        currentMilli: 1000,
        settings: const BillingSettings(priceAgorot: 500));
    expect(c.toMap(), old);
    expect(c.amountAgorot, 200);
  });
  test('zero consumption without minimum allowed as zero bill', () {
    expect(
        calculateBill(
                previousMilli: 0,
                currentMilli: 0,
                settings: const BillingSettings())
            .amountAgorot,
        0);
  });
}
