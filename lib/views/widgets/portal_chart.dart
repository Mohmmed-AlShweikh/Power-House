import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/portal_tokens.dart';

class PortalChartPoint {
  final String label;
  final double value;
  const PortalChartPoint(this.label, this.value);
}

/// Discrete values are never interpolated. Every column has a visible number.
class PortalBarChart extends StatelessWidget {
  final List<PortalChartPoint> points;
  final double maximum;
  final double progress;
  final bool horizontal;
  const PortalBarChart(
      {super.key,
      required this.points,
      required this.maximum,
      this.progress = 1,
      this.horizontal = false});
  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final secondary = theme.brightness == Brightness.dark
        ? PortalTokens.darkChartSecondary
        : PortalTokens.chartSecondary;
    final top = maximum > 0 ? maximum : 1.0;
    if (horizontal) {
      return Column(
          children: points
              .map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: PortalTokens.md),
                    child: Row(children: [
                      Expanded(child: Text(p.label, style: text.bodySmall)),
                      const SizedBox(width: PortalTokens.sm),
                      Expanded(
                          child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: FractionallySizedBox(
                                  widthFactor:
                                      (p.value / top * progress).clamp(0, 1),
                                  child: Container(
                                      height: PortalTokens.xl,
                                      color: secondary)))),
                      const SizedBox(width: PortalTokens.sm),
                      Text(p.value.toStringAsFixed(1), style: text.labelMedium),
                    ]),
                  ))
              .toList());
    }
    final width =
        math.max(points.length * PortalTokens.control, PortalTokens.zero);
    return Semantics(
        label: 'الاستهلاك بالكيلوواط ساعة',
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: math.max(
                width,
                MediaQuery.sizeOf(context).width -
                    PortalTokens.gutter * 2 -
                    PortalTokens.lg * 2),
            child: Column(children: [
              SizedBox(
                  height:
                      PortalTokens.chartHeight + PortalTokens.chartLabelHeight,
                  child: Row(
                      textDirection: TextDirection.rtl,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(
                            width: PortalTokens.chartAxisWidth,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(top.toStringAsFixed(0),
                                    style: text.labelSmall),
                                Text((top / 2).toStringAsFixed(0),
                                    style: text.labelSmall),
                                Text('0', style: text.labelSmall)
                              ],
                            )),
                        ...points.asMap().entries.map((e) => Expanded(
                                child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(e.value.value.toStringAsFixed(1),
                                    style: text.labelMedium),
                                const SizedBox(height: PortalTokens.xs),
                                Container(
                                    width: PortalTokens.chartBarWidth,
                                    height: (e.value.value /
                                            top *
                                            PortalTokens.chartHeight *
                                            progress)
                                        .clamp(PortalTokens.zero,
                                            PortalTokens.chartHeight),
                                    color: e.key == points.length - 1
                                        ? theme.colorScheme.primary
                                        : secondary),
                              ],
                            ))),
                      ])),
              const Divider(height: PortalTokens.line),
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  const SizedBox(width: PortalTokens.chartAxisWidth),
                  ...points.map((p) => Expanded(
                          child: Padding(
                        padding: const EdgeInsets.only(top: PortalTokens.sm),
                        child: Text(p.label,
                            textAlign: TextAlign.center,
                            style: text.labelSmall),
                      )))
                ],
              ),
            ]),
          ),
        ));
  }
}
