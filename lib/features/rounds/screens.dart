import 'overview.dart';
import '../finance/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../theme/portal_tokens.dart';
import '../../views/widgets/portal_components.dart';
import '../../views/widgets/portal_number.dart';
import '../billing_settings/models.dart';
import '../billing_shared/widgets.dart';
import '../metering/models.dart';
import 'models.dart';
import 'providers.dart';

class RoundsScreen extends StatelessWidget {
  const RoundsScreen({super.key});
  @override
  Widget build(BuildContext context) => const RoundsOverview();
}

class RoundScreen extends ConsumerWidget {
  final String rid;
  const RoundScreen(this.rid, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rounds = ref.watch(billingRoundsProvider);
    final matches = rounds.valueOrNull?.docs.where((d) => d.id == rid).toList();
    final data =
        matches == null || matches.isEmpty ? null : matches.single.data();
    final readingState = ref.watch(roundReadingsProvider(rid));
    final readings = readingState.valueOrNull;
    final values = {for (final d in readings?.docs ?? []) d.id: d.data()};
    return Scaffold(
        appBar: AppBar(title: const Text('قراءات الجولة')),
        body: ListView(padding: PortalTokens.pagePadding, children: [
          if (readingState.hasError)
            Column(children: [
              const PortalErrorState(
                  'تعذر تحميل القراءات بعد المحاولات التلقائية'),
              TextButton(
                  onPressed: () => ref.invalidate(roundReadingsProvider(rid)),
                  child: const Text('إعادة المحاولة'))
            ]),
          if (data != null) ...[
            Text(data['status'] == 'closed'
                ? 'الجولة مغلقة؛ التصحيح من كشف الحساب'
                : 'سجّل القراءة الحالية فقط. أكد القفزات الكبيرة، وحدد عداداً جديداً عند الاستبدال.'),
            if (data['status'] == 'preparing')
              PortalActionButton(
                  label: 'استئناف تحضير الجولة',
                  onPressed: () => featureAction(context,
                      () => ref.read(roundsRepositoryProvider).prepare(rid))),
            if(data['status']=='preparing') TextButton(onPressed:()async{if(await featureConfirm(context,'إلغاء الجولة دون حذف بيانات المشتركين؟')&&context.mounted)await featureAction(context,()=>ref.read(roundsRepositoryProvider).cancelPreparation(rid));},child:const Text('إلغاء الجولة')),
            if (['open', 'closing'].contains(data['status']))
              PortalActionButton(
                  label: data['status'] == 'closing'
                      ? 'استئناف إصدار الفواتير'
                      : 'إغلاق الجولة وإصدار الفواتير',
                  onPressed: () async {
                    if (await featureConfirm(context,
                            'إغلاق الجولة وإصدار فاتورة واحدة لكل مشترك؟') &&
                        context.mounted) {
                      await featureAction(
                          context,
                          () => ref
                              .read(roundsRepositoryProvider)
                              .closeRound(rid));
                    }
                  })
          ],
          FeatureData(
              value: ref.watch(roundAssignmentsProvider(rid)),
              retry: () => ref.invalidate(roundAssignmentsProvider(rid)),
              builder: (s) => Column(children: [
                    for (final d in s.docs)
                      Builder(builder: (context) {
                        final row = MeterAssignment.fromMap(d.id, d.data());
                        final reading = values[d.id];
                        BillingCalculation? calc;
                        if (reading != null && data != null) {
                          calc = calculateBill(
                              previousMilli: row.previousMilli,
                              currentMilli: reading['currentMilli'],
                              settings:
                                  BillingSettings.fromMap(data['settings']),
                              newMeter: reading['newMeter'] == true,
                              startingMilli: reading['startingMilli']);
                        }
                        return PortalPanel(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                              Text(row.name,
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              Text('${row.address} • ${row.number}'),
                              PortalLabelValue(
                                  label: 'السابقة',
                                  value: formatFixed(row.previousMilli, 3)),
                              PortalLabelValue(
                                  label: 'الحالية',
                                  value: reading == null
                                      ? 'لم تسجل'
                                      : formatFixed(
                                          reading['currentMilli'], 3)),
                              if (calc != null)
                                PortalLabelValue(
                                    label: calc.minimumApplied
                                        ? 'المبلغ (الحد الأدنى)'
                                        : 'المبلغ المحسوب',
                                    value:
                                        '₪${formatFixed(calc.amountAgorot, 2)}'),
                              if (data?['status'] == 'open')
                                Wrap(children: [
                                  TextButton(
                                      onPressed: () => enter(
                                          context,
                                          ref,
                                          row,
                                          false,
                                          BillingSettings.fromMap(
                                              data!['settings'])),
                                      child:
                                          const Text('تسجيل / تعديل القراءة')),
                                  TextButton(
                                      onPressed: () => enter(
                                          context,
                                          ref,
                                          row,
                                          true,
                                          BillingSettings.fromMap(
                                              data!['settings'])),
                                      child: const Text('عداد جديد'))
                                ])
                            ]));
                      })
                  ]))
        ]));
  }

  Future<void> enter(BuildContext context, WidgetRef ref, MeterAssignment row,
      bool newMeter, BillingSettings settings) async {
    final v = await featureForm(
        context, newMeter ? 'استبدال عداد' : 'القراءة الحالية', {
      'القراءة الحالية': '',
      if (newMeter) ...{'قراءة البداية الجديدة': '0', 'سبب الاستبدال': ''}
    },
        numeric: {
          'القراءة الحالية',
          'قراءة البداية الجديدة'
        }, preview: (v) {
      final c = calculateBill(
          previousMilli: row.previousMilli,
          currentMilli: parseFixed(v['القراءة الحالية']!, 3),
          settings: settings,
          newMeter: newMeter,
          startingMilli:
              newMeter ? parseFixed(v['قراءة البداية الجديدة']!, 3) : null);
      return PortalLabelValue(
          label: c.minimumApplied ? 'المبلغ (الحد الأدنى)' : 'المبلغ المحسوب',
          value: '₪${formatFixed(c.amountAgorot, 2)}');
    });
    if (v == null || !context.mounted) return;
    final n = parseFixed(v['القراءة الحالية']!, 3);
    var confirmed = false;
    if (row.abnormal(n)) {
      confirmed = await featureConfirm(
          context, 'قفزة أكبر من ثلاثة أضعاف المتوسط؛ تأكيد؟');
      if (!confirmed || !context.mounted) return;
    }
    await featureAction(
        context,
        () => ref.read(roundsRepositoryProvider).ownerReading(
            rid, row.id.substring(rid.length + 1), n,
            newMeter: newMeter,
            starting:
                newMeter ? parseFixed(v['قراءة البداية الجديدة']!, 3) : null,
            reason: v['سبب الاستبدال'] ?? '',
            confirmed: confirmed));
  }
}

class CycleStatementScreen extends ConsumerWidget {
  const CycleStatementScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(authProvider).profile?.role == UserRole.admin;
    final payments = ref.watch(cyclePaymentsProvider);
    return Scaffold(
        appBar: AppBar(title: const Text('كشف حساب الجولات')),
        body: ListView(padding: PortalTokens.pagePadding, children: [
          FeatureData(
              value: ref.watch(accountBalancesProvider),
              retry: () => ref.invalidate(accountBalancesProvider),
              builder: (s) => Column(children: [
                    for (final d in s.docs)
                      PortalLabelValue(
                          label: 'الرصيد المستحق',
                          value:
                              '₪${formatFixed(d.data()['billedAgorot'] - d.data()['collectedAgorot'], 2)}')
                  ])),
          FeatureData(
              value: ref.watch(cycleBillsProvider),
              retry: () => ref.invalidate(cycleBillsProvider),
              builder: (s) => s.docs.isEmpty
                  ? const PortalEmptyState('لا توجد فواتير جولات منشورة')
                  : Column(children: [
                      for (final d in s.docs)
                        Builder(builder: (context) {
                          final bill = CycleBill(d.id, d.data()),
                              snap = bill.snapshot,
                              settings =
                                  BillingSettings.fromMap(snap['settings']);
                          return PortalPanel(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                Text(d.data()['name'],
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                Text(
                                    '${bill.status}${d.data()['published'] ? '' : ' • لم تُنشر بعد'}'),
                                PortalNumber('₪${formatFixed(bill.amount, 2)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium),
                                PortalLabelValue(
                                    label: 'السابقة / الحالية',
                                    value:
                                        '${formatFixed(snap['previousMilli'], 3)} / ${formatFixed(snap['currentMilli'], 3)}'),
                                PortalLabelValue(
                                    label: 'الاستهلاك (${settings.unitName})',
                                    value: formatFixed(
                                        snap['differenceMilli'], 3)),
                                PortalLabelValue(
                                    label: 'سعر الوحدة',
                                    value:
                                        '₪${formatFixed(settings.priceAgorot, 2)}'),
                                if (snap['minimumApplied'])
                                  const Text('تم تطبيق الحد الأدنى'),
                                PortalLabelValue(
                                    label: 'تاريخ القراءة',
                                    value: DateTime.fromMillisecondsSinceEpoch(
                                            d.data()['date'],
                                            isUtc: true)
                                        .toIso8601String()
                                        .substring(0, 10)),
                                PortalLabelValue(
                                    label: 'المدفوع / المتبقي',
                                    value:
                                        '₪${formatFixed(bill.paid, 2)} / ₪${formatFixed(bill.outstanding, 2)}'),
                                if (bill.outstanding > 0 &&
                                    d.data()['pendingPaymentId'] == '')
                                  TextButton(
                                      onPressed: () =>
                                          pay(context, ref, bill, owner),
                                      child: const Text('تسجيل دفعة')),
                                if (owner)
                                  TextButton(
                                      onPressed: () async {
                                        final v = await featureForm(
                                            context, 'تصحيح موثق بعد الإغلاق', {
                                          'القراءة الحالية المصححة': '',
                                          'سبب التصحيح': ''
                                        }, numeric: {
                                          'القراءة الحالية المصححة'
                                        });
                                        if (v != null && context.mounted) {
                                          await featureAction(
                                              context,
                                              () => ref
                                                  .read(
                                                      roundsRepositoryProvider)
                                                  .correct(
                                                      d.id,
                                                      parseFixed(
                                                          v['القراءة الحالية المصححة']!,
                                                          3),
                                                      v['سبب التصحيح']!));
                                        }
                                      },
                                      child: const Text('تصحيح القراءة'))
                              ]));
                        })
                    ])),
          const PortalSection('سجل الدفعات'),
          FeatureData(
              value: payments,
              retry: () => ref.invalidate(cyclePaymentsProvider),
              builder: (s) => Column(children: [
                    for (final d in s.docs)
                      PortalPanel(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                            PortalNumber(
                                '₪${formatFixed(d.data()['amountAgorot'], 2)}',
                                style: Theme.of(context).textTheme.titleLarge),
                            Text('${d.data()['reference']} • ${{
                              'pending': 'قيد المراجعة',
                              'approved': 'معتمدة',
                              'rejected': 'مرفوضة',
                              'reversed': 'معكوسة'
                            }[d.data()['status']]}'),
                            PortalLabelValue(
                                label: 'تاريخ الدفع',
                                value: DateTime.fromMillisecondsSinceEpoch(
                                        d.data()['date'],
                                        isUtc: true)
                                    .toIso8601String()
                                    .substring(0, 10)),
                            PortalLabelValue(
                                label: 'الطريقة',
                                value: ({
                                      'cash': 'نقدي',
                                      'bank': 'تحويل',
                                      'wallet': 'محفظة',
                                      'other': 'أخرى'
                                    }[d.data()['method']] ??
                                    '')),
                            if (d.data()['reason'] != null)
                              Text(d.data()['reason']),
                            if (owner && d.data()['status'] == 'approved')
                              TextButton(
                                  onPressed: () async {
                                    final v = await featureForm(context,
                                        'عكس دفعة معتمدة', {'سبب العكس': ''});
                                    if (v != null && context.mounted) {
                                      await featureAction(
                                          context,
                                          () => ref
                                              .read(financeRepositoryProvider)
                                              .reversePayment(
                                                  d.id, v.values.single));
                                    }
                                  },
                                  child: const Text('عكس الدفعة')),
                            if (owner && d.data()['status'] == 'pending')
                              Wrap(children: [
                                TextButton(
                                    onPressed: () => featureAction(
                                        context,
                                        () => ref
                                            .read(roundsRepositoryProvider)
                                            .reviewPayment(d.id, true)),
                                    child: const Text('اعتماد')),
                                TextButton(
                                    onPressed: () async {
                                      final v = await featureForm(
                                          context, 'رفض الدفعة', {'السبب': ''});
                                      if (v != null && context.mounted) {
                                        await featureAction(
                                            context,
                                            () => ref
                                                .read(roundsRepositoryProvider)
                                                .reviewPayment(d.id, false,
                                                    reason: v.values.single));
                                      }
                                    },
                                    child: const Text('رفض'))
                              ])
                          ]))
                  ]))
        ]));
  }

  Future<void> pay(
      BuildContext context, WidgetRef ref, CycleBill b, bool owner) async {
    final v = await featureForm(context, 'تسجيل دفعة للمراجعة', {
      'المبلغ (₪)': formatFixed(b.outstanding, 2),
      'تاريخ الدفع (سنة-شهر-يوم)':
          DateTime.now().toIso8601String().substring(0, 10),
      'الرقم المرجعي': '',
      'طريقة الدفع (نقدي/تحويل/محفظة/أخرى)': 'نقدي'
    }, numeric: {
      'المبلغ (₪)'
    });
    if (v != null && context.mounted) {
      await featureAction(
          context,
          () => ref.read(roundsRepositoryProvider).submitPayment(b.id,
              amount: positiveMoney(v['المبلغ (₪)']!),
              date:
                  DateTime.parse('${v['تاريخ الدفع (سنة-شهر-يوم)']}T00:00:00Z')
                      .millisecondsSinceEpoch,
              reference: v['الرقم المرجعي']!,
              method: ({
                    'نقدي': 'cash',
                    'تحويل': 'bank',
                    'محفظة': 'wallet',
                    'أخرى': 'other'
                  }[v['طريقة الدفع (نقدي/تحويل/محفظة/أخرى)']] ??
                  ''),
              ownerEntry: owner));
    }
  }
}
