import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/bill_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_provider.dart';
import '../../../config/colors.dart';
import '../../../theme/portal_theme.dart';
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
      duration: const Duration(milliseconds: 600),
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
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryFor(brightness);
    final bg = brightness == Brightness.dark
        ? AppColors.darkBackground
        : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            expandedHeight: 0,
            title: Text('الاستهلاك',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Colors.white)),
            actions: const [NotificationBell()],
          ),
          SliverToBoxAdapter(
            child: billsAsync.when(
              data: (bills) {
                if (bills.isEmpty) return const _EmptyUsage();
                return _UsageBody(
                  bills: bills,
                  history: history,
                  period: _period,
                  anim: _anim,
                  onPeriodChanged: _selectPeriod,
                  primary: primary,
                  brightness: brightness,
                );
              },
              loading: () => const SizedBox(
                height: 400,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const _EmptyUsage(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Body ──────────────────────────────────────────────────────────────────

class _UsageBody extends StatelessWidget {
  final List<Bill> bills;
  final ConsumptionHistory history;
  final _Period period;
  final Animation<double> anim;
  final void Function(_Period) onPeriodChanged;
  final Color primary;
  final Brightness brightness;

  const _UsageBody({
    required this.bills,
    required this.history,
    required this.period,
    required this.anim,
    required this.onPeriodChanged,
    required this.primary,
    required this.brightness,
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

    final muted = AppColors.mutedFor(brightness);
    final surface =
        brightness == Brightness.dark ? AppColors.darkSurface : Colors.white;

    String unit = period == _Period.daily ? 'kWh/يوم' : 'kWh';
    String totalLabel = period == _Period.daily
        ? 'آخر ٧ أيام'
        : period == _Period.weekly
            ? 'آخر ٤ أسابيع'
            : 'إجمالي';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Header gradient card ──────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primary,
                  primary.withOpacity(0.75),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          const Icon(Icons.bolt, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text('الاستهلاك الكلي',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: anim,
                  builder: (_, __) => Text(
                    '${(totalVal * anim.value).toStringAsFixed(1)} kWh',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(totalLabel,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7), fontSize: 13)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _HeaderStat(
                        label: 'المتوسط',
                        value: '${avgVal.toStringAsFixed(1)} $unit'),
                    const SizedBox(width: 16),
                    _HeaderStat(
                        label: 'الأعلى',
                        value: '${maxVal.toStringAsFixed(1)} $unit'),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 16),

          // ── Period selector ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(
              children: [
                _PillButton(
                  label: 'يومي',
                  selected: period == _Period.daily,
                  onTap: () => onPeriodChanged(_Period.daily),
                  primary: primary,
                ),
                _PillButton(
                  label: 'أسبوعي',
                  selected: period == _Period.weekly,
                  onTap: () => onPeriodChanged(_Period.weekly),
                  primary: primary,
                ),
                _PillButton(
                  label: 'شهري',
                  selected: period == _Period.monthly,
                  onTap: () => onPeriodChanged(_Period.monthly),
                  primary: primary,
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 80.ms),

          const SizedBox(height: 16),

          // ── Chart card ────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      period == _Period.daily
                          ? 'آخر ٧ أيام'
                          : period == _Period.weekly
                              ? 'آخر ٤ أسابيع'
                              : 'الأشهر الأخيرة',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textFor(brightness)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('kWh',
                          style: TextStyle(
                              color: primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                AnimatedBuilder(
                  animation: anim,
                  builder: (_, __) {
                    if (period == _Period.daily) {
                      return _LineChart(
                          points: points,
                          maxVal: maxVal,
                          anim: anim.value,
                          primary: primary,
                          muted: muted);
                    } else if (period == _Period.weekly) {
                      return _HorizontalBarChart(
                          points: points,
                          maxVal: maxVal,
                          anim: anim.value,
                          primary: primary,
                          muted: muted,
                          brightness: brightness);
                    } else {
                      return _VerticalBarChart(
                          points: points,
                          maxVal: maxVal,
                          anim: anim.value,
                          primary: primary,
                          muted: muted);
                    }
                  },
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 160.ms),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ─── Header stat chip ───────────────────────────────────────────────────────

class _HeaderStat extends StatelessWidget {
  final String label, value;
  const _HeaderStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7), fontSize: 11)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

// ─── Pill button ────────────────────────────────────────────────────────────

class _PillButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color primary;

  const _PillButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? primary : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: selected
                      ? Colors.white
                      : AppColors.mutedFor(Theme.of(context).brightness),
                ),
              ),
            ),
          ),
        ),
      );
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

// ─── Line chart (daily) ─────────────────────────────────────────────────────

class _LineChart extends StatelessWidget {
  final List<_DataPoint> points;
  final double maxVal;
  final double anim;
  final Color primary;
  final Color muted;
  const _LineChart({required this.points, required this.maxVal,
    required this.anim, required this.primary, required this.muted});
  @override
  Widget build(BuildContext context) => Theme(
    data: buildPortalTheme(Theme.of(context).brightness),
    child: PortalBarChart(points: points.map((p) => PortalChartPoint(p.label, p.value)).toList(),
      maximum: maxVal, progress: anim, horizontal: false),
  );
}

class _HorizontalBarChart extends StatelessWidget {
  final List<_DataPoint> points;
  final double maxVal;
  final double anim;
  final Color primary;
  final Color muted;
  final Brightness brightness;
  const _HorizontalBarChart({required this.points, required this.maxVal,
    required this.anim, required this.primary, required this.muted, required this.brightness});
  @override
  Widget build(BuildContext context) => Theme(
    data: buildPortalTheme(Theme.of(context).brightness),
    child: PortalBarChart(points: points.map((p) => PortalChartPoint(p.label, p.value)).toList(),
      maximum: maxVal, progress: anim, horizontal: true),
  );
}

class _VerticalBarChart extends StatelessWidget {
  final List<_DataPoint> points;
  final double maxVal;
  final double anim;
  final Color primary;
  final Color muted;
  const _VerticalBarChart({required this.points, required this.maxVal,
    required this.anim, required this.primary, required this.muted});
  @override
  Widget build(BuildContext context) => Theme(
    data: buildPortalTheme(Theme.of(context).brightness),
    child: PortalBarChart(points: points.map((p) => PortalChartPoint(p.label, p.value)).toList(),
      maximum: maxVal, progress: anim, horizontal: false),
  );
}
// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyUsage extends StatelessWidget {
  const _EmptyUsage();

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.mutedFor(Theme.of(context).brightness);
    return SizedBox(
      height: 400,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bolt, size: 56, color: muted),
          const SizedBox(height: 12),
          Text('لا توجد بيانات استهلاك بعد',
              style: TextStyle(color: muted, fontSize: 15)),
        ],
      ),
    );
  }
}
