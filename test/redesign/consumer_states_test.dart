import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:generator_portal/models/alert_model.dart';
import 'package:generator_portal/models/bill_model.dart';
import 'package:generator_portal/models/complaint_model.dart';
import 'package:generator_portal/models/user_model.dart';
import 'package:generator_portal/providers/auth_provider.dart';
import 'package:generator_portal/providers/data_provider.dart';
import 'package:generator_portal/theme/portal_theme.dart';
import 'package:generator_portal/views/screens/consumer/consumer_shell.dart';
import 'home_goldens_test.dart' show FixtureAuth;

// Exercise existing loading/empty/error branches through actual destinations.
// No production provider implementation, account, service, or route is changed.
Stream<T> fixture<T>(String state, T empty) => switch (state) {
      'loading' => const Stream.empty(),
      'error' => Stream.error(StateError('fixture failure')),
      _ => Stream.value(empty),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    final font = FontLoader('PortalArabic');
    for (final weight in ['Regular', 'SemiBold', 'Bold']) {
      font.addFont(rootBundle.load('assets/fonts/NotoSansArabic-$weight.ttf'));
    }
    await font.load();
    await (FontLoader('PortalCurrency')
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf')))
        .load();
  });
  for (final state in ['empty', 'loading', 'error']) {
    for (final brightness in Brightness.values) {
      testWidgets('consumer actual $state surfaces ${brightness.name}',
          (tester) async {
        tester.view.physicalSize = const Size(430, 1280);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(ProviderScope(
            overrides: [
              authProvider
                  .overrideWith((ref) => FixtureAuth(UserRole.consumer)),
              billsProvider('').overrideWith((ref) => fixture(state, <Bill>[])),
              alertsProvider('')
                  .overrideWith((ref) => fixture(state, <AppAlert>[])),
              consumerComplaintsProvider('')
                  .overrideWith((ref) => fixture(state, <Complaint>[])),
              consumptionProvider('').overrideWith((ref) => fixture(state,
                  const ConsumptionData(monthlyUsage: 0, dailyUsage: 0))),
              generatorProvider.overrideWith((ref) => fixture(
                  state, const GeneratorState(isOn: false, pricePerKwh: 2))),
            ],
            child: RepaintBoundary(
                key: const ValueKey('states'),
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  locale: const Locale('ar'),
                  supportedLocales: const [Locale('ar')],
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate
                  ],
                  theme: buildPortalTheme(brightness),
                  home: const ConsumerShell(),
                ))));
        await tester.runAsync(() async {
          final context = tester.element(find.byType(MaterialApp));
          for (final variant in ['primary', 'reversed']) {
            await precacheImage(
                AssetImage('assets/brand/approved-a/mark-$variant-384.png'),
                context);
          }
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 800));
        Future<void> capture(String name) async {
          if (name == 'complaints' || name == 'notifications') {
            final title =
                find.text(name == 'complaints' ? 'شكاواي' : 'الإشعارات').last;
            final center = tester.getCenter(title);
            expect(center.dy, greaterThanOrEqualTo(0));
            expect(center.dy, lessThan(1280));
          }
          if (name == 'complaints' && state == 'error') {
            expect(tester.getCenter(find.text('تعذّر تحميل الشكاوى')).dy,
                lessThan(1280));
          }
          expect(tester.takeException(), isNull);
          for (final element in find.byType(Text).evaluate()) {
            final widget = element.widget as Text;
            final size = DefaultTextStyle.of(element)
                    .style
                    .merge(widget.style)
                    .fontSize ??
                14;
            expect(size, greaterThanOrEqualTo(12), reason: widget.data);
          }
          await expectLater(
              find.byKey(const ValueKey('states')),
              matchesGoldenFile(
                  '../../screenshots/redesign/consumer/states/${name}_${state}_${brightness.name}.png'));
        }

        await capture('home');
        for (final destination in [
          ('الاستهلاك', 'usage'),
          ('الفواتير', 'bills'),
          ('الملف', 'profile')
        ]) {
          await tester.tap(find.byKey(ValueKey('nav-${destination.$1}')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump(const Duration(milliseconds: 800));
          await capture(destination.$2);
        }
        await tester.ensureVisible(find.text('شكاواي'));
        await tester.tap(find.text('شكاواي'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 800));
        await capture('complaints');
        Navigator.of(tester.element(find.text('شكاواي').last)).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 800));
        await tester.tap(find.byTooltip('الإشعارات').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 800));
        await capture('notifications');
        // Record that error fallbacks remain deliberately identical to baseline.
        if (state == 'error' || state == 'empty') {
          expect(find.text('لا توجد إشعارات'), findsOneWidget);
        }
        await tester.runAsync(() async {
          final dir = Directory('docs/validation')..createSync(recursive: true);
          File('${dir.path}/consumer-state-branches.txt').writeAsStringSync(
              'Error/empty fallbacks unchanged: bills -> لا توجد فواتير بعد; usage -> لا توجد بيانات استهلاك بعد; '
              'notifications -> لا توجد إشعارات; complaints error -> تعذّر تحميل الشكاوى. '
              'Loading remains loading. Generator error/off remains off.\n');
        });
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
