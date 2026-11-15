import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:generator_portal/models/alert_model.dart';
import 'package:generator_portal/models/complaint_model.dart';
import 'package:generator_portal/models/user_model.dart';
import 'package:generator_portal/models/bill_model.dart';
import 'package:generator_portal/providers/auth_provider.dart';
import 'package:generator_portal/providers/data_provider.dart';
import 'package:generator_portal/theme/portal_theme.dart';
import 'package:generator_portal/views/screens/consumer/profile_tab.dart';
import 'package:generator_portal/views/screens/consumer/bills_tab.dart';
import 'package:generator_portal/views/screens/admin/admin_screen.dart';
import 'package:generator_portal/views/widgets/portal_keyboard.dart';
import 'redesign/home_goldens_test.dart' show FixtureAuth;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> boot(WidgetTester tester, Widget child, UserRole role,
      Brightness brightness, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FixtureAuth(role)),
          alertsProvider('').overrideWith((ref) => Stream.value(<AppAlert>[])),
          subscribersProvider.overrideWith((ref) => Stream.value(<UserProfile>[
                UserProfile(
                    uid: 'fixture',
                    name: 'مشترك',
                    role: UserRole.consumer,
                    ampereLimit: 10,
                    createdAt: DateTime(2026)),
              ])),
          subscribersMapProvider
              .overrideWith((ref) => Stream.value({'fixture': 'مشترك'})),
          billsProvider('').overrideWith((ref) => Stream.value(<Bill>[])),
          allBillsProvider.overrideWith((ref) => Stream.value(<Bill>[])),
          pendingUsersProvider
              .overrideWith((ref) => Stream.value(<UserProfile>[])),
          complaintsProvider.overrideWith((ref) => Stream.value(<Complaint>[
                Complaint(
                    id: 'fixture',
                    userId: '',
                    userName: 'مشترك',
                    text: 'شكوى تجريبية',
                    status: ComplaintStatus.open,
                    createdAt: DateTime(2026)),
              ])),
          generatorProvider.overrideWith((ref) =>
              Stream.value(const GeneratorState(isOn: true, pricePerKwh: 2))),
          monthlyBillStatsProvider.overrideWith((ref) => const MonthlyBillStats(
              unpaidCount: 0, unpaidAmount: 0, paidCount: 0, paidAmount: 0)),
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
          home: child,
        )));
    await tester.pumpAndSettle();
  }

  Future<void> keyboard(WidgetTester tester, Finder field, double inset) async {
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.showKeyboard(field);
    tester.view.viewInsets = FakeViewPadding(bottom: inset);
    await tester.pumpAndSettle();
    final bounds = tester.getRect(field);
    final topOfKeyboard = tester.view.physicalSize.height - inset;
    expect(bounds.top, greaterThanOrEqualTo(0), reason: 'field above viewport');
    expect(bounds.bottom, lessThanOrEqualTo(topOfKeyboard),
        reason: 'focused field must be completely above keyboard');
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  }

  Future<void> reachable(
      WidgetTester tester, Finder target, double inset) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    expect(tester.getRect(target).bottom,
        lessThanOrEqualTo(tester.view.physicalSize.height - inset));
    expect(tester.getRect(target).top, greaterThanOrEqualTo(0));
  }

  for (final brightness in Brightness.values) {
    for (final size in [const Size(430, 800), const Size(800, 500)]) {
      final inset = size.height > 600 ? 320.0 : 220.0;
      testWidgets('profile edit keyboard ${brightness.name} $size',
          (tester) async {
        await boot(
            tester, const ProfileTab(), UserRole.consumer, brightness, size);
        await tester.scrollUntilVisible(find.text('تعديل البيانات'), 180,
            scrollable: find.byType(Scrollable).first);
        await tester.tap(find.text('تعديل البيانات'));
        await tester.pumpAndSettle();
        final fields = find.byType(TextField);
        for (var i = 0; i < fields.evaluate().length; i++) {
          await keyboard(tester, fields.at(i), inset);
        }
        await reachable(tester, find.text('حفظ التغييرات'), inset);
        await reachable(tester, find.text('تعديل البيانات').last, inset);
      });
      testWidgets('complaint keyboard ${brightness.name} $size',
          (tester) async {
        await boot(
            tester, const ProfileTab(), UserRole.consumer, brightness, size);
        await tester.scrollUntilVisible(find.text('إرسال شكوى'), 180,
            scrollable: find.byType(Scrollable).first);
        await tester.tap(find.text('إرسال شكوى'));
        await tester.pumpAndSettle();
        await keyboard(tester, find.byType(TextField), inset);
        await reachable(
            tester, find.widgetWithText(ElevatedButton, 'إرسال الشكوى'), inset);
      });
    }
    testWidgets('admin form journey keyboard ${brightness.name}',
        (tester) async {
      const inset = 320.0;
      await boot(tester, const AdminScreen(), UserRole.admin, brightness,
          const Size(430, 800));
      Future<void> tap(Finder finder) async {
        if (finder.evaluate().isEmpty) {
          await tester.scrollUntilVisible(finder, 160,
              scrollable: find
                  .byWidgetPredicate((w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down)
                  .first);
        }
        final element = tester.element(finder);
        final scrollable = Scrollable.maybeOf(element);
        if (scrollable != null &&
            scrollable.axisDirection == AxisDirection.down) {
          await scrollable.position
              .ensureVisible(element.findRenderObject()!, alignment: 0.5);
          await tester.pumpAndSettle();
        }
        await tester.tap(finder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
      }

      Future<void> close() async {
        tester.view.viewInsets = FakeViewPadding.zero;
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.of(tester.element(find.byType(PortalFocusReveal).last)).pop();
        await tester.pumpAndSettle();
      }

      await tap(find.byKey(const ValueKey('nav-المشتركون')));
      await tap(find.widgetWithIcon(OutlinedButton, Icons.edit_outlined).first);
      await keyboard(tester, find.byType(TextField).last, inset);
      await reachable(
          tester, find.widgetWithText(ElevatedButton, 'حفظ'), inset);
      await close();
      await tap(find.byKey(const ValueKey('nav-الفواتير')));
      await tap(find.text('إضافة فاتورة'));
      await keyboard(
          tester, find.widgetWithText(TextField, 'مثال: 142.5'), inset);
      await close();
      await tap(find.byKey(const ValueKey('nav-الشكاوى')));
      await tap(find.text('الرد على الشكوى').first);
      await keyboard(tester, find.byType(TextField).last, inset);
      await reachable(
          tester, find.widgetWithText(ElevatedButton, 'إرسال الرد'), inset);
      await close();
      await tap(find.byKey(const ValueKey('nav-المزيد')));
      await tap(find.text('ملفي'));
      await tap(find.text('تعديل البيانات الشخصية'));
      final fields = find.byType(TextField);
      for (var i = 0; i < fields.evaluate().length; i++) {
        await keyboard(tester, fields.at(i), inset);
      }
      await close();
      await tap(find.byKey(const ValueKey('nav-المزيد')));
      await tap(find.text('السعر وجدول التشغيل'));
      await keyboard(tester, find.byType(TextField).last, inset);
      await close();
    });
  }

  testWidgets('long form reveals final field/title/actions on keyboard resize',
      (tester) async {
    await boot(
        tester,
        Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showPortalFormSheet(
                        context: context,
                        builder: (_) => Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('عنوان'),
                                  for (var i = 0; i < 8; i++)
                                    TextField(
                                        decoration: InputDecoration(
                                            labelText: 'حقل $i')),
                                  TextButton(
                                      onPressed: () {},
                                      child: const Text('حفظ'))
                                ]))),
                    child: const Text('فتح')))),
        UserRole.consumer,
        Brightness.light,
        const Size(430, 800));
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();
    await keyboard(tester, find.byType(TextField).last, 320);
    await reachable(tester, find.text('حفظ'), 320);
    await reachable(tester, find.text('عنوان'), 320);
  });

  testWidgets('three-field security dialog scrolls above keyboard',
      (tester) async {
    await boot(
        tester,
        Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showPortalFormDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                                scrollable: true,
                                title: const Text('تغيير كلمة المرور'),
                                content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (var i = 0; i < 3; i++)
                                        TextField(
                                            obscureText: true,
                                            decoration: InputDecoration(
                                                labelText: 'كلمة المرور $i'))
                                    ]),
                                actions: [
                                  TextButton(
                                      onPressed: () {},
                                      child: const Text('حفظ'))
                                ])),
                    child: const Text('فتح')))),
        UserRole.consumer,
        Brightness.dark,
        const Size(430, 800));
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();
    await keyboard(tester, find.byType(TextField).last, 320);
    await reachable(tester, find.text('حفظ'), 320);
  });

  testWidgets(
      'receipt remains scrollable with keyboard, no notes field invented',
      (tester) async {
    await boot(
        tester,
        Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showPortalFormSheet(
                        context: context,
                        builder: (_) => ReceiptUploadView(
                            bill: Bill(
                                id: 'fixture',
                                userId: '',
                                month: 'نوفمبر',
                                year: 2026,
                                amount: 284,
                                kwh: 142,
                                status: BillStatus.pending,
                                createdAt: DateTime(2026)),
                            bytes: null,
                            uploading: false,
                            onPick: () {},
                            onUpload: () {},
                            onClose: () {})),
                    child: const Text('فتح')))),
        UserRole.consumer,
        Brightness.light,
        const Size(430, 800));
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await reachable(tester, find.text('ارسال وصل الدفع'), 320);
    expect(tester.takeException(), isNull);
  });
}
