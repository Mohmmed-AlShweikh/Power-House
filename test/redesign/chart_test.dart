import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generator_portal/theme/portal_theme.dart';
import 'package:generator_portal/theme/portal_tokens.dart';
import 'package:generator_portal/views/widgets/portal_chart.dart';
import 'package:generator_portal/views/widgets/portal_components.dart';

void main() {
  testWidgets('chart keeps every value visible and exposes a simple axis',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildPortalTheme(Brightness.light),
      home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
              body: PortalBarChart(maximum: 30, points: [
            PortalChartPoint('الأحد', 10),
            PortalChartPoint('الاثنين', 20),
            PortalChartPoint('الثلاثاء', 30),
          ]))),
    ));
    for (final value in ['10.0', '20.0', '30.0', '0', '15', '30']) {
      expect(find.text(value), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
  test('secondary columns exceed 3:1 on both chart surfaces', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
    }

    expect(contrast(PortalTokens.chartSecondary, PortalTokens.surface),
        greaterThanOrEqualTo(3));
    expect(contrast(PortalTokens.darkChartSecondary, PortalTokens.darkSurface),
        greaterThanOrEqualTo(3));
    for (final pair in [
      (PortalTokens.working, PortalTokens.workingFill),
      (PortalTokens.darkWorking, PortalTokens.darkWorkingFill),
      (PortalTokens.muted, PortalTokens.stoppedFill),
      (PortalTokens.darkMuted, PortalTokens.darkStoppedFill),
      (PortalTokens.success, PortalTokens.successFill),
      (PortalTokens.darkSuccess, PortalTokens.darkSuccessFill),
      (PortalTokens.warning, PortalTokens.warningFill),
      (PortalTokens.darkWarning, PortalTokens.darkWarningFill),
      (PortalTokens.danger, PortalTokens.dangerFill),
      (PortalTokens.darkDanger, PortalTokens.darkDangerFill),
    ]) {
      expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
    }
    expect(PortalTokens.working, isNot(PortalTokens.primary));
  });
  test(
      'generator switch track and thumb contrast against the actual hero fills',
      () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
    }

    for (final fill in [PortalTokens.working, PortalTokens.darkWorkingFill]) {
      expect(contrast(PortalTokens.generatorSwitchTrack, fill),
          greaterThanOrEqualTo(3));
      expect(contrast(PortalTokens.generatorSwitchThumb, fill),
          greaterThanOrEqualTo(3));
    }
  });
  for (final brightness in Brightness.values) {
    for (final isOn in [true, false]) {
      testWidgets('actual switch parts contrast with hero: $brightness / $isOn',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
            theme: buildPortalTheme(brightness),
            home: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                    body: PortalGeneratorPanel(
                        isOn: isOn, detail: 'الحالة', onToggle: (_) {})))));
        final root = find.byType(PortalGeneratorPanel);
        final container = tester.widget<Container>(
            find.descendant(of: root, matching: find.byType(Container)).first);
        final fill = (container.decoration! as BoxDecoration).color!;
        final toggle = tester.widget<Switch>(find.byType(Switch));
        double contrast(Color a, Color b) {
          final x = a.computeLuminance(), y = b.computeLuminance();
          return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
        }

        for (final part in isOn
            ? [toggle.activeTrackColor!, toggle.activeThumbColor!]
            : [toggle.inactiveTrackColor!, toggle.inactiveThumbColor!]) {
          expect(contrast(part, fill), greaterThanOrEqualTo(3));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('ledger wraps long Arabic addresses on a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: buildPortalTheme(Brightness.light),
        home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
                body: Padding(
                    padding: PortalTokens.pagePadding,
                    child: PortalDataRow(
                        label: 'العنوان',
                        value:
                            'غزة، حي النور، الشارع الرئيسي بالقرب من المخبز ومركز الخدمات',
                        icon: Icons.location_on_outlined))))));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('غزة'), findsOneWidget);
  });
}
