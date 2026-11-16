import 'package:flutter/material.dart';
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
import 'package:generator_portal/views/screens/admin/admin_screen.dart';
import 'package:generator_portal/views/screens/consumer/consumer_shell.dart';
import 'package:generator_portal/views/widgets/portal_components.dart';
import 'package:generator_portal/views/widgets/portal_navigation.dart';
import 'redesign/home_goldens_test.dart' show FixtureAuth;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final subscriber = UserProfile(
      uid: 'fixture',
      name: 'مشترك الاختبار',
      idNumber: '123456789',
      phone: '0591234567',
      role: UserRole.consumer,
      ampereLimit: 10,
      createdAt: DateTime(2026));
  final bill = Bill(
      id: 'review',
      userId: 'fixture',
      month: 'نوفمبر',
      year: 2026,
      amount: 284,
      kwh: 142,
      status: BillStatus.pendingReview,
      createdAt: DateTime(2026, 11));

  Future<void> boot(
      WidgetTester tester, UserRole role, Brightness brightness) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FixtureAuth(role)),
          generatorProvider.overrideWith((ref) =>
              Stream.value(const GeneratorState(isOn: true, pricePerKwh: 2))),
          allBillsProvider.overrideWith((ref) => Stream.value([bill])),
          billsProvider('').overrideWith((ref) => Stream.value(<Bill>[])),
          billsProvider('fixture').overrideWith((ref) => Stream.value([bill])),
          subscribersProvider.overrideWith((ref) => Stream.value([subscriber])),
          subscribersMapProvider.overrideWith(
              (ref) => Stream.value({'fixture': subscriber.name})),
          consumerRequestsProvider.overrideWith(
              (ref) => ref.watch(pendingUsersProvider.future).asStream()),
          pendingUsersProvider
              .overrideWith((ref) => Stream.value(<UserProfile>[])),
          complaintsProvider.overrideWith((ref) => Stream.value(<Complaint>[])),
          alertsProvider('').overrideWith((ref) => Stream.value(<AppAlert>[])),
          consumptionProvider('').overrideWith((ref) => Stream.value(
              const ConsumptionData(monthlyUsage: 0, dailyUsage: 0))),
          monthlyBillStatsProvider.overrideWith((ref) => const MonthlyBillStats(
              unpaidCount: 1, unpaidAmount: 284, paidCount: 0, paidAmount: 0)),
          recentActivitiesProvider.overrideWith((ref) => []),
        ],
        child: MaterialApp(
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
        )));
    await tester.pumpAndSettle();
  }

  void synced(WidgetTester tester, int page, int nav, String title,
      {bool admin = true}) {
    final stack = admin
        ? find.byKey(const ValueKey('admin-pages'))
        : find.byType(IndexedStack).first;
    expect(tester.widget<IndexedStack>(stack).index, page);
    final visibleType = admin
        ? [
            '_DashboardTab',
            '_PendingUsersTab',
            '_SubscribersTab',
            '_BillsTab',
            '_ComplaintsTab',
            '_AdminProfileTab'
          ][page]
        : ['HomeTab', 'UsageTab', 'BillsTab', 'ProfileTab'][page];
    final visiblePage =
        find.byWidgetPredicate((w) => w.runtimeType.toString() == visibleType);
    expect(visiblePage, findsOneWidget);
    final pageCenter = tester.getCenter(visiblePage);
    expect(pageCenter.dx, inInclusiveRange(0, 430));
    expect(pageCenter.dy, inInclusiveRange(0, 1000));
    expect(
        tester
            .widget<PortalFloatingNavigation>(
                find.byType(PortalFloatingNavigation))
            .selected,
        nav);
    expect(
        find.descendant(
            of: find.byType(PortalIdentityBar), matching: find.text(title)),
        findsOneWidget);
    expect(find.byType(TabBarView), findsNothing);
    expect(find.byType(PageView), findsNothing);
    expect(tester.takeException(), isNull);
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(ValueKey('nav-$label')));
    await tester.pumpAndSettle();
  }

  Future<void> swipes(WidgetTester tester, VoidCallback check) async {
    for (final dx in [-260.0, 260.0]) {
      await tester.timedDragFrom(const Offset(215, 250), Offset(dx, 0),
          const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 50));
      check();
      await tester.pumpAndSettle();
      check();
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('admin page/title/nav stay synced in RTL ${brightness.name}',
        (tester) async {
      await boot(tester, UserRole.admin, brightness);
      const pages = [0, 2, 3, 4];
      const labels = ['نظرة عامة', 'المشتركون', 'الفواتير', 'الشكاوى'];
      for (var i = 0; i < labels.length; i++) {
        await tap(tester, labels[i]);
        synced(tester, pages[i], i, labels[i]);
        await swipes(tester, () => synced(tester, pages[i], i, labels[i]));
      }
      await tap(tester, 'المزيد');
      expect(find.byKey(const ValueKey('admin-more-menu')), findsOneWidget);
      expect(
          tester
              .widget<PortalFloatingNavigation>(
                  find.byType(PortalFloatingNavigation))
              .selected,
          4);
      for (final label in [
        'الطلبات',
        'ملفي',
        'السعر وجدول التشغيل',
        'تبديل المظهر',
        'تسجيل الخروج'
      ]) {
        expect(
            find.widgetWithText(ListTile, label).hitTestable(), findsOneWidget);
      }
      // Dismiss without selection: retain previous page/title/selection.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      synced(tester, 4, 3, 'الشكاوى');
      for (final entry in [(1, 'الطلبات'), (5, 'ملفي')]) {
        await tap(tester, 'المزيد');
        await tester.tap(find.widgetWithText(ListTile, entry.$2));
        await tester.pumpAndSettle();
        synced(tester, entry.$1, 4, entry.$2);
        await swipes(tester, () => synced(tester, entry.$1, 4, entry.$2));
      }
      await tap(tester, 'المزيد');
      await tester.tap(find.text('السعر وجدول التشغيل'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
      synced(tester, 5, 4, 'ملفي');
      await tap(tester, 'المزيد');
      await tester.tap(find.text('تبديل المظهر'));
      await tester.pumpAndSettle();
      synced(tester, 5, 4, 'ملفي');
      await tap(tester, 'نظرة عامة');
      synced(tester, 0, 0, 'نظرة عامة');
    });

    testWidgets('consumer already ignores main-tab swipes ${brightness.name}',
        (tester) async {
      await boot(tester, UserRole.consumer, brightness);
      const labels = ['الرئيسية', 'الاستهلاك', 'الفواتير', 'الملف'];
      for (var i = 0; i < labels.length; i++) {
        await tap(tester, labels[i]);
        synced(tester, i, i, labels[i], admin: false);
        await swipes(
            tester, () => synced(tester, i, i, labels[i], admin: false));
      }
    });
  }

  testWidgets('admin lazily retains subscriber search and bill filter state',
      (tester) async {
    await boot(tester, UserRole.admin, Brightness.light);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(AdminScreen)));
    // Unvisited tabs do not subscribe early just because state is retained.
    expect(container.exists(pendingUsersProvider), isFalse);
    expect(
        find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_PendingUsersTab',
            skipOffstage: false),
        findsNothing);
    await tap(tester, 'المشتركون');
    final search = find.byType(TextField);
    await tester.enterText(search, 'مشترك');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tap(tester, 'الفواتير');
    await tester.ensureVisible(find.text('مقبول'));
    await tester.tap(find.text('مقبول'));
    await tester.pumpAndSettle();
    await tap(tester, 'المشتركون');
    expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'مشترك');
    await tap(tester, 'الفواتير');
    expect(find.text('لا توجد فواتير'), findsOneWidget);
    synced(tester, 3, 2, 'الفواتير');
  });

  testWidgets(
      'subscriber bill shortcut still synchronizes page/title/highlight',
      (tester) async {
    await boot(tester, UserRole.admin, Brightness.light);
    await tap(tester, 'المشتركون');
    await tester.tap(find.text(subscriber.name));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مراجعة'));
    await tester.pumpAndSettle();
    synced(tester, 3, 2, 'الفواتير');
    final container =
        ProviderScope.containerOf(tester.element(find.byType(AdminScreen)));
    expect(container.read(highlightedBillProvider), bill.id);
  });
}
