import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/bill_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_provider.dart';
import '../../../theme/portal_tokens.dart';
import '../../widgets/portal_components.dart';
import '../../widgets/portal_number.dart';
import '../../widgets/portal_chart.dart';
import '../../widgets/notification_bell.dart';

enum _Period { daily, weekly, monthly }

class UsageTab extends ConsumerStatefulWidget {
  const UsageTab({super.key});

  @override
  ConsumerState<UsageTab> createState() => _UsageTabState();
}

class _UsageTabState extends ConsumerState<UsageTab>
    with SingleTickerProviderStateMixin {
  _Period _period = _Period.monthly;
  late final AnimationController _animCtrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: PortalTokens.motion,
    );
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _selectPeriod(_Period p) {
    if (_period == p) return;
    setState(() => _period = p);
    _animCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider).profile;
    final uid = profile?.uid ?? '';
    final billsAsync = ref.watch(billsProvider(uid));
    final history = ref.watch(consumptionHistoryProvider(uid));
    return PortalPage(
        title: 'الاستهلاك',
        subtitle: 'بيانات الاستهلاك',
        actions: const [
          NotificationBell()
        ],
        children: [
          billsAsync.when(
            data: (bills) {
              if (bills.isEmpty) return const _EmptyUsage();
              return _UsageBody(
                  bills: bills,
                  history: history,
                  period: _period,
                  anim: _anim,
                  onPeriodChanged: _selectPeriod);
            },
            loading: () => const Padding(
                padding: PortalTokens.pagePadding,
                child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const _EmptyUsage(),
          ),
        ]);
  }
}

// ─── Body ──────────────────────────────────────────────────────────────────

class _UsageBody extends StatelessWidget {
  final List<Bill> bills;
  final ConsumptionHistory history;
  final _Period period;
  final Animation<double> anim;
  final void Function(_Period) onPeriodChanged;

  const _UsageBody({
    required this.bills,
    required this.history,
    required this.period,
    required this.anim,
    required this.onPeriodChanged,
  });

  List<_DataPoint> _buildPoints() {
    if (period == _Period.daily) {
      return history.daily
          .map((p) => _DataPoint(
                label: p.label,
                value: p.kwh,
                cost: p.cost,
                isToday: false,
              ))
          .toList();
    }

    if (period == _Period.weekly) {
      return history.weekly
          .map((p) => _DataPoint(
                label: p.label,
                value: p.kwh,
                cost: p.cost,
              ))
          .toList();
    }

    return history.monthly
        .map((p) => _DataPoint(label: p.label, value: p.kwh, cost: p.cost))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final points = _buildPoints();
    final maxVal =
        points.isEmpty ? 1.0 : points.map((p) => p.value).reduce(max);
    final totalVal = points.fold(0.0, (s, p) => s + p.value);
    final avgVal = points.isEmpty ? 0.0 : totalVal / points.length;

    String unit = period == _Period.daily ? 'kWh/يوم' : 'kWh';
    String totalLabel = period == _Period.daily
        ? 'آخر ٧ أيام'
        : period == _Period.weekly
            ? 'آخر ٤ أسابيع'
            : 'إجمالي';
    final text = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PortalPanel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('الاستهلاك الكلي', style: text.titleMedium),
        const SizedBox(height: PortalTokens.md),
        AnimatedBuilder(
            animation: anim,
            builder: (_, __) => PortalNumber(
                '${(totalVal * anim.value).toStringAsFixed(1)} kWh',
                style: text.displaySmall)),
        Text(totalLabel, style: text.bodySmall),
        const SizedBox(height: PortalTokens.lg),
        const Divider(),
        PortalDataRow(
            label: 'المتوسط',
            value: '${avgVal.toStringAsFixed(1)} $unit',
            icon: Icons.analytics_outlined),
        PortalDataRow(
            label: 'الأعلى',
            value: '${maxVal.toStringAsFixed(1)} $unit',
            icon: Icons.trending_up),
      ])),
      const PortalSection('الفترة'),
      Row(children: [
        for (final item in [
          (_Period.daily, 'يومي'),
          (_Period.weekly, 'أسبوعي'),
          (_Period.monthly, 'شهري')
        ])
          Expanded(
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: PortalTokens.xs),
                  child: Semantics(
                      selected: period == item.$1,
                      child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: PortalTokens.sm),
                              backgroundColor: period == item.$1
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : null,
                              side: BorderSide(
                                  width: period == item.$1
                                      ? PortalTokens.focusLine
                                      : PortalTokens.line,
                                  color: period == item.$1
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .outlineVariant)),
                          onPressed: () => onPeriodChanged(item.$1),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (period == item.$1) ...[
                                  const Icon(Icons.check,
                                      size: PortalTokens.lg),
                                  const SizedBox(width: PortalTokens.xs)
                                ],
                                Text(item.$2),
                              ]))))),
      ]),
      PortalSection(
          period == _Period.daily
              ? 'آخر ٧ أيام'
              : period == _Period.weekly
                  ? 'آخر ٤ أسابيع'
                  : 'الأشهر الأخيرة',
          trailing: Text('kWh', style: text.labelMedium)),
      PortalPanel(
          child: AnimatedBuilder(
              animation: anim,
              builder: (_, __) => PortalBarChart(
                  points: (period == _Period.monthly ? points.reversed : points)
                      .map((p) => PortalChartPoint(p.label, p.value))
                      .toList(),
                  maximum: maxVal,
                  progress: anim.value,
                  horizontal: false))),
    ]);
  }
}

// ─── Data point ─────────────────────────────────────────────────────────────

class _DataPoint {
  final String label;
  final double value;
  final int cost;
  final bool isToday;
  const _DataPoint(
      {required this.label,
      required this.value,
      required this.cost,
      this.isToday = false});
}

class _EmptyUsage extends StatelessWidget {
  const _EmptyUsage();
  @override
  Widget build(BuildContext context) =>
      const PortalEmptyState('لا توجد بيانات استهلاك بعد', icon: Icons.bolt);
}
