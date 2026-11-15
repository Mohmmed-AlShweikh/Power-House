import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
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
import 'package:generator_portal/views/screens/admin/admin_screen.dart';
import 'package:generator_portal/views/screens/admin/subscriber_details_screen.dart';
import 'package:generator_portal/views/screens/login_screen.dart';
import 'package:generator_portal/views/screens/consumer/bills_tab.dart';
import 'package:generator_portal/views/screens/register_screen.dart';
import 'package:generator_portal/views/screens/setup_screen.dart';
import 'package:generator_portal/views/screens/super_admin/super_admin_screen.dart';
import 'package:generator_portal/views/widgets/portal_components.dart';
import 'home_goldens_test.dart' show FixtureAuth;
import 'consumer_states_test.dart' show fixture;

class AuthReview extends FixtureAuth {
  AuthReview(super.role);
  Completer<String?>? pending;
  @override
  Future<String?> login(String idNumber, String password) =>
      (pending = Completer<String?>()).future;
  @override
  Future<String?> register(
          {required String idNumber,
          required String name,
          required String address,
          required String password,
          required UserRole role}) =>
      (pending = Completer<String?>()).future;
}

Future<String> receiptFixture() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 320, 220),
      Paint()..color = PortalTokens.surface);
  var y = 16.0;
  for (final line in ['إيصال تجريبي', 'محمد أحمد', 'أكتوبر 2026', '₪310']) {
    final painter = TextPainter(
        textDirection: TextDirection.rtl,
        text: TextSpan(
            text: line,
            style: PortalTokens.type.titleLarge?.copyWith(
                fontFamily: PortalTokens.font,
                fontFamilyFallback: PortalTokens.fallback,
                color: PortalTokens.text)));
    painter.layout(maxWidth: 288);
    painter.paint(canvas, Offset(304 - painter.width, y));
    y += 46;
  }
  final pic = recorder.endRecording();
  final img = await pic.toImage(320, 220);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  final data = base64Encode(bytes!.buffer.asUint8List());
  img.dispose();
  pic.dispose();
  return data;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    final font = FontLoader(PortalTokens.font);
    for (final weight in ['Regular', 'SemiBold', 'Bold']) {
      font.addFont(rootBundle.load('assets/fonts/NotoSansArabic-$weight.ttf'));
    }
    await font.load();
    await (FontLoader('PortalCurrency')
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf')))
        .load();
  });
  for (final brightness in Brightness.values) {
    testWidgets(
        'admin complete destination and dialog journey ${brightness.name}',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();

      final receipt = (await tester.runAsync(receiptFixture))!;
      final now = DateTime.now();
      final sub = UserProfile(
          uid: 'fixture-consumer',
          name: 'محمد أحمد',
          phone: '0591234567',
          address: 'غزة، حي النور',
          role: UserRole.consumer,
          idNumber: '123456789',
          ampereLimit: 10,
          createdAt: DateTime(2025, 1, 1));
      final pending = sub.copyWith(approvalStatus: ApprovalStatus.pending);
      final bills = [
        Bill(
            id: 'pending',
            userId: sub.uid,
            month: 'نوفمبر',
            year: now.year,
            amount: 284,
            kwh: 142,
            status: BillStatus.pending,
            createdAt: now),
        Bill(
            id: 'review',
            userId: sub.uid,
            month: 'أكتوبر',
            year: now.year,
            amount: 310,
            kwh: 155,
            status: BillStatus.pendingReview,
            receiptBase64: receipt,
            createdAt: DateTime(now.year, 10, 28)),
        Bill(
            id: 'paid',
            userId: sub.uid,
            month: 'سبتمبر',
            year: now.year,
            amount: 268,
            kwh: 134,
            status: BillStatus.paid,
            createdAt: DateTime(now.year, 9, 28)),
        Bill(
            id: 'rejected',
            userId: sub.uid,
            month: 'أغسطس',
            year: now.year,
            amount: 246,
            kwh: 123,
            status: BillStatus.rejected,
            createdAt: DateTime(now.year, 8, 28)),
      ];
      final complaints = [
        Complaint(
            id: 'open',
            userId: sub.uid,
            userName: sub.name,
            text: 'أرجو مراجعة قراءة الاستهلاك هذا الشهر.',
            status: ComplaintStatus.open,
            createdAt: now.subtract(const Duration(hours: 2))),
        Complaint(
            id: 'resolved',
            userId: sub.uid,
            userName: sub.name,
            text: 'انقطع التشغيل مساء أمس.',
            status: ComplaintStatus.resolved,
            reply: 'تمت مراجعة الشكوى وإعادة التشغيل.',
            createdAt: now.subtract(const Duration(days: 1))),
      ];
      await tester.pumpWidget(ProviderScope(overrides: [
        authProvider.overrideWith((ref) => FixtureAuth(UserRole.admin)),
        generatorProvider.overrideWith((ref) => Stream.value(GeneratorState(
            isOn: true,
            pricePerKwh: 2,
            lastChanged: now.subtract(const Duration(hours: 2)),
            scheduledOnAt: DateTime(now.year, 11, 15, 8),
            scheduledOffAt: DateTime(now.year, 11, 15, 20)))),
        allBillsProvider.overrideWith((ref) => Stream.value(bills)),
        billsProvider(sub.uid).overrideWith((ref) => Stream.value(bills)),
        subscribersProvider.overrideWith((ref) => Stream.value([sub])),
        subscribersMapProvider
            .overrideWith((ref) => Stream.value({sub.uid: sub.name})),
        pendingUsersProvider.overrideWith((ref) => Stream.value([pending])),
        complaintsProvider.overrideWith((ref) => Stream.value(complaints)),
        alertsProvider('').overrideWith((ref) => Stream.value(<AppAlert>[])),
        monthlyBillStatsProvider.overrideWith((ref) => const MonthlyBillStats(
            unpaidCount: 1, unpaidAmount: 284, paidCount: 0, paidAmount: 0)),
        recentActivitiesProvider.overrideWith((ref) => [
              ActivityItem(
                  name: sub.name,
                  action: 'رفع إيصال أكتوبر',
                  createdAt: now,
                  color: PortalTokens.primary)
            ]),
      ], child: _Frame(brightness: brightness, child: const AdminScreen())));
      await _precache(tester, receipt: receipt);
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        await tester.runAsync(() async {
          for (final element in find.byType(Image).evaluate()) {
            await precacheImage((element.widget as Image).image, element,
                onError: (_, __) {});
          }
        });
        await tester.pump();
        expect(tester.takeException(), isNull);
        _auditText(tester);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(
            find.byKey(const ValueKey('frame')),
            matchesGoldenFile(
                '../../screenshots/redesign/admin/${name}_${brightness.name}.png'));
      }

      Future<void> dismiss() async {
        Navigator.of(tester.element(find.byType(Dialog).last)).pop();
        await tester.pumpAndSettle();
      }

      Future<void> nav(String label) async {
        await tester.tap(find.byKey(ValueKey('nav-$label')));
        await tester.pumpAndSettle();
      }

      await capture('overview');
      // Assert actual label/value columns, independently of bidi glyph appearance.
      final price = find.byKey(const ValueKey('generator-price-zoom'));
      final texts = find.descendant(of: price, matching: find.byType(Text));
      expect(tester.getCenter(texts.first).dx,
          greaterThan(tester.getCenter(texts.last).dx));
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      await capture('generator_confirmation');
      await dismiss();
      await nav('المشتركون');
      await capture('subscribers');
      await tester
          .tap(find.widgetWithIcon(OutlinedButton, Icons.edit_outlined).first);
      await tester.pumpAndSettle();
      await capture('ampere_dialog');
      await dismiss();
      await tester.tap(find.text(sub.name).first);
      await tester.pumpAndSettle();
      await capture('subscriber_details');
      await tester.tap(find.text('مراجعة').first);
      await tester.pumpAndSettle();
      expect(find.byType(SubscriberDetailsScreen), findsNothing);
      await capture('bills');
      final review = find
          .ancestor(
              of: find.text('بانتظار المراجعة'),
              matching: find.byType(PortalInvoiceRow))
          .first;
      await tester.tap(review);
      await tester.pumpAndSettle();
      await capture('receipt_review');
      await dismiss();
      await tester.tap(find.text('إضافة فاتورة'));
      await tester.pumpAndSettle();
      await capture('add_bill');
      await tester.enterText(
          find.widgetWithText(TextField, 'مثال: 142.5'), '142.5');
      await tester.pumpAndSettle();
      await capture('bill_calculation');
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
      await nav('الشكاوى');
      await capture('complaints');
      await tester.tap(find.text('الرد على الشكوى').first);
      await tester.pumpAndSettle();
      await capture('reply_dialog');
      await dismiss();
      await nav('المزيد');
      await capture('more');
      await tester.tap(find.text('الطلبات'));
      await tester.pumpAndSettle();
      await capture('requests');
      await nav('المزيد');
      await tester.tap(find.text('ملفي'));
      await tester.pumpAndSettle();
      await capture('profile');
      await tester.ensureVisible(find.text('تعديل البيانات الشخصية'));
      await tester.tap(find.text('تعديل البيانات الشخصية'));
      await tester.pumpAndSettle();
      await capture('edit_profile');
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
      await nav('المزيد');
      await tester.tap(find.text('السعر وجدول التشغيل'));
      await tester.pumpAndSettle();
      await capture('generator_settings');
      await tester.tap(find.text('تشغيل 08:00'));
      await tester.pumpAndSettle();
      await capture('time_picker');
      Navigator.of(tester.element(find.byType(TimePickerDialog))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('auth and source-only setup ${brightness.name}',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();

      late AuthReview auth;
      Future<void> boot(Widget child) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(ProviderScope(overrides: [
          authProvider
              .overrideWith((ref) => auth = AuthReview(UserRole.consumer))
        ], child: _Frame(brightness: brightness, child: child)));
        await _precache(tester);
        await tester.pumpAndSettle();
      }

      Future<void> capture(String name) async {
        await tester.runAsync(() async {
          for (final element in find.byType(Image).evaluate()) {
            await precacheImage((element.widget as Image).image, element,
                onError: (_, __) {});
          }
        });
        await tester.pump();
        expect(tester.takeException(), isNull);
        _auditText(tester);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(
            find.byKey(const ValueKey('frame')),
            matchesGoldenFile(
                '../../screenshots/redesign/auth/${name}_${brightness.name}.png'));
      }

      await boot(const LoginScreen());
      await capture('login');
      await tester.tap(find.text('نسيت كلمة المرور؟'));
      await tester.pumpAndSettle();
      await capture('forgot_empty_id');
      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'xxxxxxxxxx'), '123456789');
      await tester.tap(find.text('نسيت كلمة المرور؟'));
      await tester.pumpAndSettle();
      await capture('forgot_guidance');
      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, '••••••••'), 'test-password');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'تسجيل الدخول'));
      await tester.pump(const Duration(milliseconds: 400));
      await capture('login_loading');
      auth.pending!.complete('رقم الهوية أو كلمة المرور غير صحيحة');
      await tester.pumpAndSettle();
      await capture('login_error');
      await boot(const RegisterScreen());
      await capture('register_consumer');
      await tester.tap(find.text('تقديم الطلب'));
      await tester.pumpAndSettle();
      await capture('register_validation');
      await tester.tap(find.text('صاحب مولد'));
      await tester.pumpAndSettle();
      await capture('register_owner');
      for (final value in [
        ('xxxxxxxxxx', '123456789'),
        ('اسم المولد', 'مولد حي النور'),
        ('المدينة / الحي', 'غزة، حي النور'),
        ('8 أحرف على الأقل', 'test-password'),
        ('أعد كتابة كلمة المرور', 'test-password')
      ]) {
        final field = find.widgetWithText(TextField, value.$1);
        await tester.ensureVisible(field);
        await tester.enterText(field, value.$2);
      }
      await tester.ensureVisible(find.text('تقديم الطلب'));
      await tester.tap(find.text('تقديم الطلب'));
      await tester.pump(const Duration(milliseconds: 400));
      await capture('register_loading');
      auth.pending!.complete(null);
      await tester.pumpAndSettle();
      await capture('register_success');
      await boot(const SetupScreen());
      await capture('setup_source_only');
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        'superadmin populated, diagnostic dialog and global error ${brightness.name}',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(ProviderScope(
          overrides: [
            authProvider
                .overrideWith((ref) => FixtureAuth(UserRole.superAdmin)),
            pendingGeneratorOwnersProvider.overrideWith((ref) => Stream.value([
                  UserProfile(
                      uid: 'owner-fixture',
                      name: 'مولد حي النور',
                      role: UserRole.admin,
                      approvalStatus: ApprovalStatus.pending,
                      idNumber: '123456789',
                      address: 'غزة، حي النور',
                      createdAt: DateTime(2026, 11, 14)),
                ])),
          ],
          child:
              _Frame(brightness: brightness, child: const SuperAdminScreen())));
      await _precache(tester);
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        expect(tester.takeException(), isNull);
        _auditText(tester);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(
            find.byKey(const ValueKey('frame')),
            matchesGoldenFile(
                '../../screenshots/redesign/admin/${name}_${brightness.name}.png'));
      }

      await capture('superadmin');
      // Pure presentation dialog extracted from the existing Firestore diagnostic.
      // No SDK initialization, query or write. Runtime still supplies its original info/callback.
      final context = tester.element(find.byType(SuperAdminScreen));
      unawaited(showDialog(
          context: context,
          builder: (dialogContext) => PortalDiagnosticDialog(
              title: 'بيانات الفايرستور',
              info: 'النتيجة التجريبية\nأصحاب المولدات: 1\nبانتظار الموافقة: 1',
              onClose: () => Navigator.pop(dialogContext))));
      await tester.pumpAndSettle();
      await capture('diagnostic_success');
      await tester.tap(find.text('حسناً'));
      await tester.pumpAndSettle();
      unawaited(showDialog(
          context: context,
          builder: (dialogContext) => PortalDiagnosticDialog(
              title: 'خطأ بالاستكشاف',
              info: 'تعذّر تحميل البيانات (بيانات اختبار)',
              onClose: () => Navigator.pop(dialogContext))));
      await tester.pumpAndSettle();
      await capture('diagnostic_error');
      await tester.pumpWidget(_Frame(
          brightness: brightness,
          child:
              const PortalExceptionView('تعذّر عرض الواجهة (بيانات اختبار)')));
      await tester.pumpAndSettle();
      await capture('global_error');
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('receipt preview and busy presentation ${brightness.name}',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final receipt = (await tester.runAsync(receiptFixture))!;
      final bill = Bill(
          id: 'receipt-fixture',
          userId: '',
          month: 'أكتوبر',
          year: 2026,
          amount: 310,
          kwh: 155,
          status: BillStatus.pending,
          createdAt: DateTime(2026, 10, 28));
      await tester.pumpWidget(ProviderScope(overrides: [
        authProvider.overrideWith((ref) => FixtureAuth(UserRole.consumer)),
        billsProvider('').overrideWith((ref) => Stream.value([bill])),
        alertsProvider('').overrideWith((ref) => Stream.value(<AppAlert>[])),
      ], child: _Frame(brightness: brightness, child: const BillsTab())));
      await _precache(tester, receipt: receipt);
      await tester.pumpAndSettle();
      for (final busy in [false, true]) {
        final context = tester.element(find.byType(BillsTab));
        unawaited(showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (dialogContext) => ReceiptUploadView(
                bill: bill,
                bytes: base64Decode(receipt),
                uploading: busy,
                onPick: () {},
                onUpload: () {},
                onClose: () => Navigator.pop(dialogContext))));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.runAsync(() async {
          for (final el in find.byType(Image).evaluate()) {
            await precacheImage((el.widget as Image).image, el);
          }
        });
        await tester.pump();
        expect(tester.takeException(), isNull);
        _auditText(tester);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(
            find.byKey(const ValueKey('frame')),
            matchesGoldenFile(
                '../../screenshots/redesign/consumer/upload_${busy ? 'loading' : 'selected'}_${brightness.name}.png'));
        await tester.tap(find.byIcon(Icons.close).last);
        await tester.pumpAndSettle();
      }
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    for (final state in ['empty', 'loading', 'error']) {
      testWidgets('admin and superadmin $state ${brightness.name}',
          (tester) async {
        tester.view.physicalSize = const Size(430, 1280);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Future<void> boot(Widget child, UserRole role) async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(ProviderScope(overrides: [
            authProvider.overrideWith((ref) => FixtureAuth(role)),
            generatorProvider.overrideWith(
                (ref) => fixture(state, const GeneratorState(isOn: false))),
            allBillsProvider.overrideWith((ref) => fixture(state, <Bill>[])),
            subscribersProvider
                .overrideWith((ref) => fixture(state, <UserProfile>[])),
            subscribersMapProvider
                .overrideWith((ref) => fixture(state, <String, String>{})),
            pendingUsersProvider
                .overrideWith((ref) => fixture(state, <UserProfile>[])),
            complaintsProvider
                .overrideWith((ref) => fixture(state, <Complaint>[])),
            pendingGeneratorOwnersProvider
                .overrideWith((ref) => fixture(state, <UserProfile>[])),
            monthlyBillStatsProvider.overrideWith((ref) =>
                const MonthlyBillStats(
                    unpaidCount: 0,
                    unpaidAmount: 0,
                    paidCount: 0,
                    paidAmount: 0)),
            recentActivitiesProvider.overrideWith((ref) => []),
          ], child: _Frame(brightness: brightness, child: child)));
          await _precache(tester);
          await tester.pump(const Duration(milliseconds: 400));
        }

        Future<void> capture(String name) async {
          expect(tester.takeException(), isNull);
          _auditText(tester);
          await expectLater(
              find.byKey(const ValueKey('frame')),
              matchesGoldenFile(
                  '../../screenshots/redesign/admin/states/${name}_${state}_${brightness.name}.png'));
        }

        await boot(const AdminScreen(), UserRole.admin);
        await capture('overview');
        for (final destination in [
          ('المشتركون', 'subscribers'),
          ('الفواتير', 'bills'),
          ('الشكاوى', 'complaints')
        ]) {
          await tester.tap(find.byKey(ValueKey('nav-${destination.$1}')));
          await tester.pump(const Duration(milliseconds: 400));
          await capture(destination.$2);
        }
        await tester.tap(find.byKey(const ValueKey('nav-المزيد')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.tap(find.text('الطلبات'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await capture('requests');
        await boot(const SuperAdminScreen(), UserRole.superAdmin);
        await capture('superadmin');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

class _Frame extends StatelessWidget {
  final Brightness brightness;
  final Widget child;
  const _Frame({required this.brightness, required this.child});
  @override
  Widget build(BuildContext context) => RepaintBoundary(
      key: const ValueKey('frame'),
      child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildPortalTheme(brightness),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate
          ],
          home: child));
}

Future<void> _precache(WidgetTester tester, {String? receipt}) async {
  await tester.runAsync(() async {
    final context = tester.element(find.byType(MaterialApp));
    for (final variant in ['primary', 'reversed']) {
      await precacheImage(
          AssetImage('assets/brand/approved-a/mark-$variant-384.png'), context);
    }
    if (receipt != null) {
      await precacheImage(MemoryImage(base64Decode(receipt)), context);
    }
  });
}

void _auditText(WidgetTester tester) {
  for (final element in find.byType(Text).evaluate()) {
    final widget = element.widget as Text;
    final size =
        DefaultTextStyle.of(element).style.merge(widget.style).fontSize ?? 14;
    expect(size, greaterThanOrEqualTo(12), reason: widget.data);
  }
}
