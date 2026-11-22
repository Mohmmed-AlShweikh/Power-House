import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:generator_portal/models/bill_model.dart';
import 'package:generator_portal/providers/data_provider.dart';

void main() {
  test('history totals use issued bill amounts after tariff changes', () async {
    final price = StateProvider<double>((_) => 2);
    final bill = Bill(
        id: 'b',
        userId: 'c',
        month: 'نوفمبر',
        year: 2026,
        amount: 42,
        kwh: 1,
        status: BillStatus.pending,
        createdAt: DateTime(2026));
    final container = ProviderContainer(overrides: [
      currentPriceProvider.overrideWith((ref) => ref.watch(price)),
      billsProvider('c').overrideWith((ref) => Stream.value([bill])),
      consumptionProvider('c')
          .overrideWith((ref) => Stream.value(const ConsumptionData()))
    ]);
    addTearDown(container.dispose);
    await container.read(billsProvider('c').future);
    await container.read(consumptionProvider('c').future);
    expect(container.read(consumptionHistoryProvider('c')).monthly.single.cost,
        42);
    container.read(price.notifier).state = 99;
    final history = container.read(consumptionHistoryProvider('c'));
    expect(history.monthly.single.cost, 42);
    expect(history.weekly.single.cost, 42);
  });
}
