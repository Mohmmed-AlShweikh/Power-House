import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generator_portal/theme/portal_theme.dart';
import 'package:generator_portal/theme/portal_tokens.dart';
import 'package:generator_portal/views/widgets/portal_navigation.dart';
import 'package:generator_portal/views/widgets/portal_number.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final font = FontLoader(PortalTokens.font)
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'));
    await font.load();
  });

  test('amount isolation preserves the source and Latin currency/unit order',
      () {
    for (final value in [
      'سعر kWh: ₪2.00',
      '₪3408',
      '142 kWh',
      '36 فاتورة',
      '08:00 - 20:00'
    ]) {
      final isolated = PortalNumber.isolate(value);
      expect(isolated.replaceAll('\u2066', '').replaceAll('\u2069', ''), value);
    }
    expect(
        PortalNumber.isolate('سعر kWh: ₪2.00'), 'سعر \u2066kWh: ₪2.00\u2069');
    expect(PortalNumber.isolate('₪3408'), '\u2066₪3408\u2069');
  });

  testWidgets('three navigation structures side by side, both roles and themes',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: buildPortalTheme(Brightness.light),
      debugShowCheckedModeBanner: false,
      home: const Directionality(
          textDirection: TextDirection.rtl,
          child: RepaintBoundary(
              key: ValueKey('review'), child: _NavigationBoard())),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(PortalFloatingNavigation), findsNWidgets(12));
    for (final bar in find.byType(PortalFloatingNavigation).evaluate()) {
      expect(tester.getSize(find.byWidget(bar.widget)).height,
          lessThanOrEqualTo(80));
      for (final target in find
          .descendant(
              of: find.byWidget(bar.widget), matching: find.byType(InkWell))
          .evaluate()) {
        final size = tester.getSize(find.byWidget(target.widget));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    }
    await expectLater(
        find.byKey(const ValueKey('review')),
        matchesGoldenFile(
            '../../screenshots/redesign/navigation_alternatives.png'));
  });

  for (final alternative in PortalNavAlternative.values) {
    testWidgets('navigation $alternative: 320dp, RTL and 48dp targets',
        (tester) async {
      tester.view.physicalSize = const Size(320, 160);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: buildPortalTheme(Brightness.light),
        home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                  child: PortalFloatingNavigation(
                      items: adminNavItems,
                      selected: 0,
                      onSelected: (_) {},
                      alternative: alternative)),
            )),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final first = find.byKey(const ValueKey('nav-نظرة عامة'));
      final last = find.byKey(const ValueKey('nav-المزيد'));
      expect(
          tester.getCenter(first).dx, greaterThan(tester.getCenter(last).dx));
      for (final target in find.byType(InkWell).evaluate()) {
        final size = tester.getSize(find.byWidget(target.widget));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      for (final item in adminNavItems) {
        expect(find.text(item.label), findsOneWidget);
      }
    });
  }
}

class _NavigationBoard extends StatelessWidget {
  const _NavigationBoard();
  static const titles = [
    '١ · البلاطات المرتفعة — موصى به',
    '٢ · جزر مستقلة',
    '٣ · نافذة التركيز'
  ];
  static const reasons = [
    [
      'بلاطات مرتفعة داخل شريط عائم.',
      'أقرب للوصف، والنشط بارز بالشكل والارتفاع.'
    ],
    ['جزر مستقلة بدل الحاوية الواحدة.', 'حد واضح ومؤشر سفلي دون ارتفاع.'],
    ['نافذة تتسع للوجهة الحالية.', 'اسم بجانب الرمز ومساحة أوسع للنشط.'],
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
          body: Padding(
        padding: const EdgeInsets.all(PortalTokens.xxl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ثلاثة اتجاهات للتنقل',
              style: Theme.of(context).textTheme.headlineLarge),
          Text(
              'مشترك: ٤ وجهات · أدمن: ٥ وجهات · عربي فاتح وداكن · النشط والغير نشط معًا',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: PortalTokens.xl),
          Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(
                  3,
                  (i) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: PortalTokens.sm),
                          child: Card(
                              child: Padding(
                            padding: const EdgeInsets.all(PortalTokens.md),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(titles[i],
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  const SizedBox(height: PortalTokens.sm),
                                  for (final line in reasons[i])
                                    Text(line,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  const SizedBox(height: PortalTokens.lg),
                                  for (final brightness in [
                                    Brightness.light,
                                    Brightness.dark
                                  ])
                                    for (final admin in [false, true])
                                      _Example(
                                          alternative:
                                              PortalNavAlternative.values[i],
                                          brightness: brightness,
                                          admin: admin),
                                ]),
                          )),
                        ),
                      ))),
          const SizedBox(height: PortalTokens.xl),
          Text(
              'الارتفاع الكامل 80dp · هدف اللمس ≥ 48dp · تسميات ظاهرة دائمًا · بلا ضبابية أو تدرجات',
              style: Theme.of(context).textTheme.bodyMedium),
        ]),
      ));
}

class _Example extends StatelessWidget {
  final PortalNavAlternative alternative;
  final Brightness brightness;
  final bool admin;
  const _Example(
      {required this.alternative,
      required this.brightness,
      required this.admin});
  @override
  Widget build(BuildContext context) => Theme(
        data: buildPortalTheme(brightness),
        child: Builder(
            builder: (context) => ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: PortalTokens.sm),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                              padding: const EdgeInsetsDirectional.only(
                                  start: PortalTokens.lg),
                              child: Text(
                                  '${admin ? 'أدمن' : 'مشترك'} · ${brightness == Brightness.dark ? 'داكن' : 'فاتح'}',
                                  style:
                                      Theme.of(context).textTheme.labelMedium)),
                          PortalFloatingNavigation(
                              items: admin ? adminNavItems : consumerNavItems,
                              selected: admin ? 2 : 1,
                              onSelected: (_) {},
                              alternative: alternative),
                        ]),
                  ),
                )),
      );
}
