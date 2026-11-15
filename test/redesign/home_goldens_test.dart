import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
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
import 'package:generator_portal/theme/portal_tokens.dart';
import 'package:generator_portal/views/widgets/portal_components.dart';
import 'package:generator_portal/views/widgets/portal_navigation.dart';
import 'package:generator_portal/views/screens/admin/admin_screen.dart';
import 'package:generator_portal/views/screens/consumer/consumer_shell.dart';

// No Firebase initialization, network, credentials, account provisioning or writes.
// Empty fixture uid means the existing AdminScreen alert listener returns early.
// The production listener and all providers remain unchanged.
class FixtureAuth extends StateNotifier<AuthState> implements AuthNotifier {
  FixtureAuth(UserRole role)
      : super(AuthState(
            loading: false,
            profile: UserProfile(
              uid: '',
              name: role == UserRole.admin ? 'مولد حي النور' : 'محمد أحمد',
              address: 'غزة، حي النور',
              role: role,
              ampereLimit: 10,
              createdAt: DateTime(2025, 1, 1),
            )));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final family in ['PortalArabic', 'PortalCurrency']) {
      final loader = FontLoader(family);
      if (family == 'PortalArabic') {
        for (final weight in ['Regular', 'SemiBold', 'Bold']) {
          loader.addFont(
              rootBundle.load('assets/fonts/NotoSansArabic-$weight.ttf'));
        }
      } else {
        loader.addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
      }
      await loader.load();
    }
  });

  for (final role in [UserRole.consumer, UserRole.admin]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final name = '${role.name}_${brightness.name}';
      testWidgets('home golden $name', (tester) async {
        final semantics = tester.ensureSemantics();
        tester.view.physicalSize = const Size(430, 1280);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final now = DateTime.now();
        final bill = Bill(
            id: 'fixture',
            userId: '',
            month: currentMonthArabic(),
            year: now.year,
            amount: 284,
            kwh: 142,
            status: BillStatus.pending,
            createdAt: now);
        await tester.pumpWidget(ProviderScope(
            overrides: [
              authProvider.overrideWith((ref) => FixtureAuth(role)),
              generatorProvider
                  .overrideWith((ref) => Stream.value(GeneratorState(
                        isOn: true,
                        pricePerKwh: 2,
                        lastChanged: now.subtract(const Duration(hours: 2)),
                        scheduledOnAt: DateTime(2026, 1, 1, 8),
                        scheduledOffAt: DateTime(2026, 1, 1, 20),
                      ))),
              billsProvider('')
                  .overrideWith((ref) => Stream.value(role == UserRole.admin
                      ? [bill]
                      : [
                          bill,
                          Bill(
                              id: 'review',
                              userId: '',
                              month: 'أكتوبر',
                              year: 2025,
                              amount: 310,
                              kwh: 155,
                              status: BillStatus.pendingReview,
                              createdAt: now),
                          Bill(
                              id: 'rejected',
                              userId: '',
                              month: 'سبتمبر',
                              year: 2025,
                              amount: 246,
                              kwh: 123,
                              status: BillStatus.rejected,
                              createdAt: now),
                          Bill(
                              id: 'paid',
                              userId: '',
                              month: 'أغسطس',
                              year: 2025,
                              amount: 268,
                              kwh: 134,
                              status: BillStatus.paid,
                              createdAt: now),
                        ])),
              consumerComplaintsProvider('')
                  .overrideWith((ref) => Stream.value([
                        Complaint(
                            id: 'complaint',
                            userId: '',
                            userName: 'محمد أحمد',
                            text: 'أرجو مراجعة انقطاع التشغيل مساء أمس.',
                            status: ComplaintStatus.resolved,
                            createdAt: DateTime(2026, 11, 12),
                            reply: 'تمت مراجعة الشكوى وإعادة التشغيل.'),
                        Complaint(
                            id: 'open',
                            userId: '',
                            userName: 'محمد أحمد',
                            text: 'استفسار عن قراءة الاستهلاك هذا الشهر.',
                            status: ComplaintStatus.open,
                            createdAt: DateTime(2026, 11, 14)),
                      ])),
              alertsProvider('').overrideWith((ref) => Stream.value([
                    AppAlert(
                        id: 'fixture',
                        title: 'فاتورة جديدة',
                        body: 'يرجى مراجعة الفاتورة المستحقة.',
                        type: AlertType.newBill,
                        createdAt: now.subtract(const Duration(hours: 1)),
                        read: false),
                  ])),
              consumptionProvider('').overrideWith((ref) => Stream.value(
                  const ConsumptionData(monthlyUsage: 142, dailyUsage: 4.7))),
              allBillsProvider.overrideWith((ref) => Stream.value([bill])),
              subscribersProvider.overrideWith((ref) => Stream.value([
                    UserProfile(
                        uid: 'fixture-consumer',
                        name: 'محمد أحمد',
                        role: UserRole.consumer,
                        createdAt: DateTime(2025)),
                  ])),
              complaintsProvider
                  .overrideWith((ref) => Stream.value(<Complaint>[])),
              pendingUsersProvider
                  .overrideWith((ref) => Stream.value(<UserProfile>[])),
              subscribersMapProvider
                  .overrideWith((ref) => Stream.value({'': 'محمد أحمد'})),
              monthlyBillStatsProvider.overrideWith((ref) =>
                  const MonthlyBillStats(
                      unpaidCount: 12,
                      unpaidAmount: 3408,
                      paidCount: 24,
                      paidAmount: 6816)),
              recentActivitiesProvider.overrideWith((ref) => [
                    ActivityItem(
                        name: 'محمد أحمد',
                        action: 'رفع إيصال نوفمبر',
                        createdAt: now,
                        color: PortalTokens.primary)
                  ]),
            ],
            child: RepaintBoundary(
                key: const ValueKey('golden'),
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
                  home: role == UserRole.admin
                      ? const AdminScreen()
                      : const ConsumerShell(),
                ))));
        await tester.runAsync(() async {
          final context = tester.element(find.byType(MaterialApp));
          await precacheImage(
              const AssetImage('assets/brand/approved-a/mark-primary-384.png'),
              context);
          await precacheImage(
              const AssetImage('assets/brand/approved-a/mark-reversed-384.png'),
              context);
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getRect(find.byType(PortalBrandMark)).right,
            lessThanOrEqualTo(430));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        expect(find.text('المولد يعمل الآن'), findsOneWidget);
        expect(Directionality.of(tester.element(find.text('المولد يعمل الآن'))),
            TextDirection.rtl);
        await expectLater(find.byKey(const ValueKey('golden')),
            matchesGoldenFile('../../screenshots/redesign/$name.png'));
        final fontRows = <Map<String, Object>>[];
        void auditText({Finder? within}) {
          final texts = within == null
              ? find.byType(Text)
              : find.descendant(of: within, matching: find.byType(Text));
          for (final element in texts.evaluate()) {
            final widget = element.widget as Text;
            final style =
                DefaultTextStyle.of(element).style.merge(widget.style);
            final size = style.fontSize ?? 14;
            expect(size, greaterThanOrEqualTo(12),
                reason: widget.data ?? 'rich text');
            fontRows.add({'text': widget.data ?? 'rich text', 'sp': size});
          }
        }

        Future<void> capture(String surface) async {
          auditText();
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          expect(tester.takeException(), isNull);
          await expectLater(
              find.byKey(const ValueKey('golden')),
              matchesGoldenFile(
                  '../../screenshots/redesign/consumer/${surface}_${brightness.name}.png'));
        }

        Future<void> zoom(String key, String surface) async {
          final boundary = tester
              .renderObject<RenderRepaintBoundary>(find.byKey(ValueKey(key)));
          await tester.runAsync(() async {
            final img = await boundary.toImage(pixelRatio: 3);
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            final dir = Directory('screenshots/redesign/details')
              ..createSync(recursive: true);
            File('${dir.path}/${surface}_${brightness.name}.png')
                .writeAsBytesSync(bytes!.buffer.asUint8List());
            img.dispose();
          });
        }

        auditText();
        if (role == UserRole.admin) {
          await zoom('generator-switch-zoom', 'admin_switch');
          await zoom('generator-price-zoom', 'admin_price');
          for (final label in [
            'المشتركون',
            'الفواتير',
            'الشكاوى',
            'نظرة عامة'
          ]) {
            await tester.tap(find.byKey(ValueKey('nav-$label')));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          for (final label in ['الطلبات', 'ملفي']) {
            await tester.tap(find.byKey(const ValueKey('nav-المزيد')));
            await tester.pumpAndSettle();
            await tester.tap(find.text(label).last);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await tester.tap(find.byKey(const ValueKey('nav-المزيد')));
          await tester.pumpAndSettle();
          auditText(within: find.byKey(const ValueKey('admin-more-menu')));
          expect(find.text('تسجيل الخروج'), findsWidgets);
          expect(find.text('تبديل المظهر'), findsOneWidget);
          await tester.tap(find.text('السعر وجدول التشغيل'));
          await tester.pumpAndSettle();
          expect(find.text('السعر الحالي لكل كيلوواط/ساعة'), findsOneWidget);
          await tester.tap(find.byIcon(Icons.close).last);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('nav-نظرة عامة')));
          await tester.pumpAndSettle();
        } else {
          expect(find.byTooltip('تسجيل الخروج'), findsNothing);
          await tester.tap(find.byKey(const ValueKey('nav-الملف')));
          await tester.pumpAndSettle();
          expect(find.text('تسجيل الخروج'), findsWidgets);
          await capture('profile');
          for (final item in [
            ('تعديل البيانات', 'edit_profile'),
            ('إرسال شكوى', 'complaint'),
            ('شكاواي', 'complaints')
          ]) {
            await tester.ensureVisible(find.text(item.$1).first);
            await tester.tap(find.text(item.$1).first);
            await tester.pumpAndSettle();
            await capture(item.$2);
            if (item.$2 == 'complaint') {
              // Existing empty validation only; never submit a complaint or hit Firebase.
              await tester
                  .tap(find.widgetWithText(ElevatedButton, 'إرسال الشكوى'));
              await tester.pumpAndSettle();
              expect(find.text('يرجى كتابة نص الشكوى'), findsOneWidget);
              await capture('complaint_validation');
            }
            await tester.tap(find.byIcon(Icons.close).last);
            await tester.pumpAndSettle();
          }
          for (final item in [('الفواتير', 'bills'), ('الاستهلاك', 'usage')]) {
            await tester.tap(find.byKey(ValueKey('nav-${item.$1}')));
            await tester.pumpAndSettle();
            await capture(item.$2);
            if (item.$2 == 'bills') {
              await tester.tap(find.text('ارسال وصل').first);
              await tester.pumpAndSettle();
              expect(find.text('اختر صورة أولاً'), findsOneWidget);
              await capture('upload_receipt');
              await tester.tap(find.byIcon(Icons.close).last);
              await tester.pumpAndSettle();
              // Rejected bill retains the original receipt action too.
              await tester.tap(find.text('تم رفض الوصل').first);
              await tester.pumpAndSettle();
              expect(find.text('اختر صورة أولاً'), findsOneWidget);
              await tester.tap(find.byIcon(Icons.close).last);
              await tester.pumpAndSettle();
            } else {
              for (final period in [
                ('يومي', 'usage_daily'),
                ('أسبوعي', 'usage_weekly')
              ]) {
                await tester.tap(find.text(period.$1));
                await tester.pumpAndSettle();
                await capture(period.$2);
              }
            }
          }
          await tester.tap(find.byTooltip('الإشعارات').first);
          await tester.pumpAndSettle();
          expect(find.text('مسح الكل'), findsOneWidget);
          await capture('notifications');
          Navigator.of(tester.element(find.text('مسح الكل'))).pop();
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('nav-الرئيسية')));
          await tester.pumpAndSettle();
        }
        // Last record can be brought fully above the overlaid floating bar.
        final scrolling = role == UserRole.admin
            ? find.byType(SingleChildScrollView).first
            : find.byType(ListView).first;
        await tester.drag(scrolling, const Offset(0, -1500));
        await tester.pumpAndSettle();
        auditText();
        expect(tester.takeException(), isNull);
        final floatingTop =
            tester.getTopLeft(find.byType(PortalFloatingNavigation)).dy;
        final lastRecord = find.byType(PortalRecordRow).last;
        if (lastRecord.evaluate().isNotEmpty) {
          expect(tester.getBottomLeft(lastRecord).dy,
              lessThanOrEqualTo(floatingTop));
        }
        await tester.runAsync(() async {
          final dir = Directory('docs/validation')..createSync(recursive: true);
          File('${dir.path}/font-sizes-$name.json').writeAsStringSync(
              const JsonEncoder.withIndent('  ').convert(fontRows));
        });
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
