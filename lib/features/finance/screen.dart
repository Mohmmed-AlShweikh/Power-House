import '../metering/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/portal_tokens.dart';
import '../../views/widgets/portal_components.dart';
import '../billing_settings/models.dart';
import '../billing_shared/widgets.dart';
import '../rounds/providers.dart';
import '../rounds/models.dart';
import 'models.dart';
import 'providers.dart';
import 'ledger.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});
  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  late FinancePeriod period = (
    kind: 'month',
    key: utcDay(DateTime.now().millisecondsSinceEpoch).substring(0, 7),
    end: ''
  );
  @override
  Widget build(BuildContext context) {
    final control = ref.watch(financeControlProvider);
    ref.watch(readerOpenRoundProvider);
    final rounds = [
      ...?ref.watch(billingRoundsProvider).valueOrNull?.docs
    ]..sort(
        (a, b) => (a.data()['date'] as int).compareTo(b.data()['date'] as int));
    return Scaffold(
        appBar: AppBar(title: const Text('المالية')),
        body: ListView(padding: PortalTokens.pagePadding, children: [
          const Text(
              'المبالغ بالأغورات الصحيحة؛ الربح = المقبوض المعتمد − المصروفات. الذمم تخص فواتير الفترة المختارة، والمقبوض حسب تاريخ الدفع.'),
          Wrap(spacing: PortalTokens.sm, children: [
            ChoiceChip(
                label: const Text('هذا الشهر'),
                selected: period.kind == 'month',
                onSelected: (_) => setState(() => period = (
                      kind: 'month',
                      key: utcDay(DateTime.now().millisecondsSinceEpoch)
                          .substring(0, 7),
                      end: ''
                    ))),
            ChoiceChip(
                label: const Text('الجولة'),
                selected: period.kind == 'round',
                onSelected: rounds.isEmpty
                    ? null
                    : (_) => setState(() => period = (
                          kind: 'round',
                          key: ref
                                  .read(readerOpenRoundProvider)
                                  .valueOrNull
                                  ?.data()?['roundId'] as String? ??
                              rounds.last.id,
                          end: ''
                        ))),
            ActionChip(
                label: const Text('فترة مخصصة'),
                onPressed: () async {
                  final r = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now());
                  if (r != null && context.mounted) {
                    if (r.duration.inDays > 366) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('اختر فترة لا تتجاوز 366 يوماً')));
                      return;
                    }
                    setState(() => period = (
                          kind: 'day',
                          key: r.start.toIso8601String().substring(0, 10),
                          end: r.end.toIso8601String().substring(0, 10)
                        ));
                  }
                })
          ]),
          if (period.kind == 'round')
            DropdownButtonFormField<String>(
                initialValue: period.key,
                decoration: const InputDecoration(labelText: 'الجولة'),
                items: [
                  for (final r in rounds)
                    DropdownMenuItem(
                        value: r.id, child: Text(utcDay(r.data()['date'])))
                ],
                onChanged: (v) =>
                    setState(() => period = (kind: 'round', key: v!, end: ''))),
          FeatureData(
              value: control,
              retry: () => ref.invalidate(financeControlProvider),
              builder: (d) => d.exists
                  ? Text(d.data()?['locked'] == true
                      ? 'إعادة الحساب جارية؛ العمليات المالية متوقفة مؤقتاً'
                      : 'ملخصات محفوظة؛ لا تُحمّل جميع الفواتير لعرض الأرقام')
                  : const PortalEmptyState(
                      'أعد حساب الملخصات مرة أولى لتهيئة المالية')),
          if (control.valueOrNull?.exists == true)
            FeatureData(
                value: ref.watch(financeTotalsProvider(period)),
                retry: () => ref.invalidate(financeTotalsProvider(period)),
                builder: (t) => Column(children: [
                      PortalPanel(
                          child: Column(children: [
                        PortalLabelValue(
                            label: 'إجمالي الفواتير',
                            value: '₪${formatFixed(t.billed, 2)}'),
                        PortalLabelValue(
                            label: 'المقبوض المعتمد',
                            value: '₪${formatFixed(t.collected, 2)}'),
                        PortalLabelValue(
                            label: 'الذمم المستحقة',
                            value: '₪${formatFixed(t.outstanding, 2)}'),
                        PortalLabelValue(
                            label: 'المصروفات',
                            value: '₪${formatFixed(t.costs, 2)}'),
                        PortalLabelValue(
                            label: 'صافي الربح', value: moneyText(t.profit))
                      ])),
                      const PortalSection('تفصيل المصروفات'),
                      for (final c in expenseCategories.entries)
                        PortalLabelValue(
                            label: c.value,
                            value:
                                '₪${formatFixed(t.categories[c.key] ?? 0, 2)}')
                    ])),
          FeatureData(
              value: ref.watch(
                  financeTotalsProvider((kind: 'total', key: 'all', end: ''))),
              retry: () => ref.invalidate(
                  financeTotalsProvider((kind: 'total', key: 'all', end: ''))),
              builder: (t) => PortalLabelValue(
                  label: 'الرصيد النقدي الكلي (دون رصيد افتتاحي)',
                  value: moneyText(t.profit))),
          PortalActionButton(
              label: 'إضافة مصروف',
              onPressed: () => editExpense(context, null, null)),
          FeatureData(
              value: ref.watch(expensesProvider(period)),
              retry: () => ref.invalidate(expensesProvider(period)),
              builder: (s) {
                final rows = s.docs.where((d) {
                  final data = d.data(), day = utcDay(data['date']);
                  return period.kind == 'round'
                      ? data['roundId'] == period.key
                      : period.kind == 'month'
                          ? day.startsWith(period.key)
                          : day.compareTo(period.key) >= 0 &&
                              day.compareTo(period.end) <= 0;
                });
                return Column(children: [
                  for (final d in rows)
                    ListTile(
                        leading: const Icon(Icons.payments_outlined),
                        title:
                            Text(expenseCategories[d.data()['category']] ?? ''),
                        subtitle: Text(
                            '${utcDay(d.data()['date'])} • ${d.data()['note']}'),
                        trailing: Wrap(children: [
                          TextButton(
                              onPressed: () =>
                                  editExpense(context, d.id, d.data()),
                              child: Text(
                                  '₪${formatFixed(d.data()['amountAgorot'], 2)} • تعديل')),
                          IconButton(
                              tooltip: 'حذف المصروف مع حفظ الأثر',
                              onPressed: () async {
                                if (await featureConfirm(context,
                                        'حذف المصروف؟ يُحفظ أثر التغيير') &&
                                    context.mounted) {
                                  await featureAction(
                                      context,
                                      () => ref
                                          .read(financeRepositoryProvider)
                                          .expense(
                                              id: d.id,
                                              amount: d.data()['amountAgorot'],
                                              date: d.data()['date'],
                                              category: d.data()['category'],
                                              note: d.data()['note'],
                                              roundId: d.data()['roundId'],
                                              remove: true));
                                }
                              },
                              icon: const Icon(Icons.delete_outline))
                        ]))
                ]);
              }),
          const Text(
              'تُعرض حتى 200 حركة تفصيلية للفترة؛ الملخص يشمل جميع الحركات. ضيّق الفترة عند الحاجة.'),
          const Text(
              'إعادة الحساب عملية إصلاح تقرأ السجلات مرة واحدة، وتحفظ جيلاً جديداً دون حذف القديم. قد تستهلك حصة ملحوظة.'),
          TextButton(
              onPressed: () async {
                if (await featureConfirm(context, 'إعادة حساب الملخصات؟') &&
                    context.mounted) {
                  await featureAction(context,
                      () => ref.read(financeRepositoryProvider).rebuild());
                }
              },
              child: const Text('إعادة حساب الملخصات'))
        ]));
  }

  String moneyText(int value) =>
      '${value < 0 ? '−' : ''}₪${formatFixed(value.abs(), 2)}';
  Future<void> editExpense(
      BuildContext context, String? id, Map<String, dynamic>? old) async {
    final v = await featureForm(context, 'بيانات المصروف', {
      'المبلغ (₪)': old == null ? '' : formatFixed(old['amountAgorot'], 2),
      'التاريخ (سنة-شهر-يوم)': old == null
          ? utcDay(DateTime.now().millisecondsSinceEpoch)
          : utcDay(old['date']),
      'الفئة (وقود/صيانة/أجور/معدات/أخرى)': old == null
          ? 'وقود'
          : expenseCategories[old['category']]!.split(' / ').first,
      'ملاحظة': old?['note'] ?? ''
    }, numeric: {
      'المبلغ (₪)'
    }, optional: {
      'ملاحظة'
    });
    if (v == null || !context.mounted) return;
    await featureAction(
        context,
        () => ref.read(financeRepositoryProvider).expense(
            id: id,
            amount: positiveMoney(v['المبلغ (₪)']!),
            date: DateTime.parse('${v['التاريخ (سنة-شهر-يوم)']}T00:00:00Z')
                .millisecondsSinceEpoch,
            category: ({
                  'وقود': 'fuel',
                  'صيانة': 'maintenance',
                  'أجور': 'wages',
                  'معدات': 'equipment',
                  'أخرى': 'other'
                }[v['الفئة (وقود/صيانة/أجور/معدات/أخرى)']] ??
                ''),
            note: v['ملاحظة']!,
            roundId: old?['roundId'] ??
                (period.kind == 'round' ? period.key : 'manual')));
  }
}
