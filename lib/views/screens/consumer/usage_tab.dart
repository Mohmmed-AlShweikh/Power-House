import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/bill_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_provider.dart';
import '../../../config/colors.dart';
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

  const _LineChart({
    required this.points,
    required this.maxVal,
    required this.anim,
    required this.primary,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              painter: _LinePainter(
                  points: points,
                  maxVal: maxVal,
                  anim: anim,
                  primary: primary,
                  muted: muted),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: points
                .map((p) => SizedBox(
                      width: 36,
                      child: Text(
                        p.label.length > 3 ? p.label.substring(0, 3) : p.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: p.isToday ? primary : muted,
                          fontWeight:
                              p.isToday ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<_DataPoint> points;
  final double maxVal;
  final double anim;
  final Color primary;
  final Color muted;

  _LinePainter({
    required this.points,
    required this.maxVal,
    required this.anim,
    required this.primary,
    required this.muted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final n = points.length;
    final dx = size.width / (n - 1);

    List<Offset> pts = List.generate(n, (i) {
      final x = i * dx;
      final ratio = maxVal > 0 ? (points[i].value / maxVal) : 0.0;
      final y = size.height - (ratio * size.height * 0.85 * anim) - 4;
      return Offset(x, y);
    });

    // Area fill
    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primary.withOpacity(0.25 * anim),
          primary.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final areaPath = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      final cp1 = Offset((pts[i - 1].dx + pts[i].dx) / 2, pts[i - 1].dy);
      final cp2 = Offset((pts[i - 1].dx + pts[i].dx) / 2, pts[i].dy);
      areaPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
    }
    areaPath
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(areaPath, areaPaint);

    // Line
    final linePaint = Paint()
      ..color = primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final linePath = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      final cp1 = Offset((pts[i - 1].dx + pts[i].dx) / 2, pts[i - 1].dy);
      final cp2 = Offset((pts[i - 1].dx + pts[i].dx) / 2, pts[i].dy);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    // Dots
    for (int i = 0; i < pts.length; i++) {
      final isToday = points[i].isToday;
      canvas.drawCircle(pts[i], isToday ? 6.0 : 4.0,
          Paint()..color = isToday ? primary : primary.withOpacity(0.5));
      canvas.drawCircle(
          pts[i], isToday ? 3.5 : 2.0, Paint()..color = Colors.white);

      if (isToday) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${points[i].value.toStringAsFixed(1)}',
            style: TextStyle(
                color: primary, fontSize: 10, fontWeight: FontWeight.w700),
          ),
          textDirection: TextDirection.rtl,
        )..layout();
        tp.paint(canvas, Offset(pts[i].dx - tp.width / 2, pts[i].dy - 20));
      }
    }

    // Horizontal grid lines
    final gridPaint = Paint()
      ..color = muted.withOpacity(0.12)
      ..strokeWidth = 1;
    for (int i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.anim != anim || old.points != points;
}

// ─── Horizontal bar chart (weekly) ──────────────────────────────────────────

class _HorizontalBarChart extends StatelessWidget {
  final List<_DataPoint> points;
  final double maxVal;
  final double anim;
  final Color primary;
  final Color muted;
  final Brightness brightness;

  const _HorizontalBarChart({
    required this.points,
    required this.maxVal,
    required this.anim,
    required this.primary,
    required this.muted,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: points.reversed.map((p) {
        final ratio = maxVal > 0 ? (p.value / maxVal) : 0.0;
        final isLast = p == points.last;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              SizedBox(
                width: 68,
                child: Text(
                  p.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isLast ? primary : muted,
                    fontWeight: isLast ? FontWeight.w700 : FontWeight.normal,
                  ),
                  textAlign: TextAlign.start,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 22,
                      decoration: BoxDecoration(
                        color: muted.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: ratio * anim,
                      child: Container(
                        height: 22,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isLast
                                ? [primary, primary.withOpacity(0.7)]
                                : [
                                    primary.withOpacity(0.4),
                                    primary.withOpacity(0.2)
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                child: Text(
                  '${p.value.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isLast ? primary : muted,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Vertical bar chart (monthly) ───────────────────────────────────────────

class _VerticalBarChart extends StatelessWidget {
  final List<_DataPoint> points;
  final double maxVal;
  final double anim;
  final Color primary;
  final Color muted;

  const _VerticalBarChart({
    required this.points,
    required this.maxVal,
    required this.anim,
    required this.primary,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: points.map((p) {
                final ratio = maxVal > 0 ? (p.value / maxVal) : 0.0;
                final isLast = p == points.last;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isLast)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${p.value.toInt()}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          height: ratio * 130 * anim,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isLast
                                  ? [primary, primary.withOpacity(0.7)]
                                  : [
                                      primary.withOpacity(0.35),
                                      primary.withOpacity(0.15)
                                    ],
                            ),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(7)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: points.map((p) {
              final isLast = p == points.last;
              return Expanded(
                child: Text(
                  p.label.length > 3 ? p.label.substring(0, 3) : p.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: isLast ? primary : muted,
                    fontWeight: isLast ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
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
