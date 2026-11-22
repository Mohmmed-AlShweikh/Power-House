import 'package:flutter_test/flutter_test.dart';
import 'package:generator_portal/features/finance/repository.dart';
import 'package:generator_portal/features/finance/models.dart';
import 'package:generator_portal/services/tenant_store.dart';
import '../support/billing_fixture.dart';

void main() {
  test(
      'approval, reversal, expense edit/delete and repair keep summaries exact',
      () async {
    final f = BillingFixture();
    await f.seed();
    final rid = await f.closed(), id = '${rid}_c';
    final finance = FinanceRepository(TenantStore(f.db, () => 'o'));
    await finance.rebuild();
    var control =
        (await f.db.collection('financeControl').doc('g').get()).data()!;
    Future<FinanceTotals> total() async => FinanceTotals.fromMap((await f.db
            .collection('financeSummaries')
            .doc('g_${control['generation']}_total_all')
            .get())
        .data()!);
    expect((await total()).billed, 28000);
    expect((await total()).outstanding, 28000);
    await f.db.collection('cycleBills').doc(id).update({'published': true});
    await f.consumer.submitPayment(id,
        amount: 10000, date: 1794700800000, reference: 'R', method: 'cash');
    final pid = (await f.db.collection('cycleBills').doc(id).get())
        .data()!['pendingPaymentId'];
    await f.owner.reviewPayment(pid, true);
    await f.owner.reviewPayment(pid, true);
    expect((await total()).collected, 10000);
    expect((await total()).outstanding, 18000);
    await finance.expense(
        id: 'e',
        amount: 3000,
        date: 1794700800000,
        category: 'fuel',
        note: 'وقود',
        roundId: rid);
    expect((await total()).profit, 7000);
    await finance.expense(
        id: 'e',
        amount: 4000,
        date: 1794700800000,
        category: 'wages',
        note: 'تصحيح',
        roundId: rid);
    expect((await total()).costs, 4000);
    expect((await total()).categories['fuel'], 0);
    expect((await total()).categories['wages'], 4000);
    await finance.reversePayment(pid, 'إلغاء المرجع');
    await finance.reversePayment(pid, 'إلغاء المرجع');
    expect((await total()).collected, 0);
    expect((await total()).outstanding, 28000);
    await finance.expense(
        id: 'e',
        amount: 4000,
        date: 1794700800000,
        category: 'wages',
        note: 'إلغاء',
        roundId: rid,
        remove: true);
    expect((await total()).costs, 0);
    expect((await f.db.collection('expenses').doc('e').get()).exists, true);
    expect((await f.db.collection('expenseChanges').get()).size, 3);
    await finance.rebuild();
    control = (await f.db.collection('financeControl').doc('g').get()).data()!;
    expect((await total()).billed, 28000);
    expect((await total()).collected, 0);
    expect((await total()).costs, 0);
  });
  test('profit integer math and category totals', () {
    final a = FinanceTotals.fromMap(
        {'collectedAgorot': 101, 'costAgorot': 250, 'fuelAgorot': 250});
    expect(a.profit, -149);
    expect((a + const FinanceTotals(collected: 149)).profit, 0);
  });
}
