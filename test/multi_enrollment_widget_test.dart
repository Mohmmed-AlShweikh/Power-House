import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:generator_portal/config/auth_redirect.dart';
import 'package:generator_portal/models/generator_model.dart';
import 'package:generator_portal/models/user_model.dart';
import 'package:generator_portal/providers/auth_provider.dart';
import 'package:generator_portal/providers/enrollment_provider.dart';
import 'package:generator_portal/providers/tenant_provider.dart';
import 'package:generator_portal/services/phone_auth_service.dart';
import 'package:generator_portal/theme/portal_theme.dart';
import 'package:generator_portal/views/screens/account_status_screen.dart';
import 'package:generator_portal/views/screens/generator_requests_screen.dart';
import 'package:generator_portal/views/screens/phone_enrollment_screen.dart';
import 'support/multi_auth_fixture.dart';

class FakePhoneGateway implements PhoneGateway {
  String? phone, verificationId, code;
  bool fail = false;
  @override
  Future<void> send(String value,
      {required void Function(String) codeSent,
      required void Function(String) failed}) async {
    phone = value;
    if (fail) {
      failed('تعذّر إرسال الرمز');
    } else {
      codeSent('fake-verification');
    }
  }

  @override
  Future<void> verify(String id, String value) async {
    verificationId = id;
    code = value;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const a = GeneratorAccount(
      id: 'a',
      name: 'مولد النور',
      sector: 'الرمال',
      status: GeneratorApproval.approved,
      ownerUid: 'PRIVATE_OWNER');
  const b = GeneratorAccount(
      id: 'b',
      name: 'مولد الأمل',
      sector: 'الشجاعية',
      status: GeneratorApproval.approved);
  Future<void> boot(WidgetTester tester, Widget child, Brightness brightness,
      {MultiAuthFixture? auth,
      FakePhoneGateway? phone,
      UserRole role = UserRole.consumer,
      AsyncValue<List<GeneratorAccount>>? directory,
      AsyncValue<List<GeneratorAccount>>? requests,
      AsyncValue<GeneratorAccount>? tenant,
      FakeFirebaseFirestore? db}) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => auth ?? MultiAuthFixture()),
          enrollmentRoleProvider.overrideWith((ref) => role),
          if (phone != null) phoneGatewayProvider.overrideWithValue(phone),
          if (directory != null)
            generatorDirectoryProvider.overrideWith((ref) => directory.when(
                data: (d) => Stream.value(d),
                error: (e, s) => Stream.error(e, s),
                loading: () => const Stream.empty())),
          if (requests != null)
            generatorRequestsProvider.overrideWith((ref) => requests.when(
                data: (d) => Stream.value(d),
                error: (e, s) => Stream.error(e, s),
                loading: () => const Stream.empty())),
          tenantAccessProvider.overrideWithValue(tenant),
          if (db != null) firestoreProvider.overrideWithValue(db),
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
            home: child)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final target = find.text(text);
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(target, 180,
          scrollable: find.byType(Scrollable).first);
    }
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets('OTP code send/verify and validation ${brightness.name}',
        (tester) async {
      final gateway = FakePhoneGateway();
      await boot(tester, const PhoneEnrollmentScreen(), brightness,
          phone: gateway);
      await tapText(tester, 'إرسال رمز التحقق');
      expect(
          find.text('أدخل رقم الهاتف مع رمز الدولة، مثل +970'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '+970591234567');
      await tapText(tester, 'إرسال رمز التحقق');
      expect(gateway.phone, '+970591234567');
      await tester.enterText(find.byType(TextField).last, '123456');
      await tapText(tester, 'تحقق ومتابعة');
      expect(gateway.verificationId, 'fake-verification');
      expect(gateway.code, '123456');
    });
    testWidgets(
        'owner form uses verified phone and submits generator/sector ${brightness.name}',
        (tester) async {
      final auth = MultiAuthFixture(AuthState(
          user: PhoneUser('new'),
          needsRegistration: true,
          startupResolved: true,
          loading: false));
      await boot(tester, const EnrollmentFormScreen(), brightness,
          auth: auth, role: UserRole.admin);
      await tester.enterText(find.byType(TextField).first, 'مولد الحي');
      await tester.enterText(find.byType(TextField).last, 'الرمال');
      await tapText(tester, 'تقديم الطلب');
      expect(auth.submittedName, 'مولد الحي');
      expect(auth.submittedSector, 'الرمال');
    });
    testWidgets(
        'picker shows no owner data and searches/filters/selects ${brightness.name}',
        (tester) async {
      final auth = MultiAuthFixture(AuthState(
          user: PhoneUser('new'),
          needsRegistration: true,
          startupResolved: true,
          loading: false));
      await boot(tester, const EnrollmentFormScreen(), brightness,
          auth: auth, directory: const AsyncData([a, b]));
      await tester.enterText(find.byType(TextField).first, 'أحمد');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الرمال').last);
      await tester.pumpAndSettle();
      expect(find.text('مولد الأمل'), findsNothing);

      expect(find.text('PRIVATE_OWNER'), findsNothing);
      await tester.enterText(find.byType(TextField).last, 'النور');
      await tester.pumpAndSettle();
      expect(find.text('مولد النور'), findsOneWidget);
      expect(find.text('مولد الأمل'), findsNothing);
      await tapText(tester, 'مولد النور');
      await tapText(tester, 'تقديم الطلب');
      expect(auth.submittedGenerator, 'a');
      expect(auth.submittedName, 'أحمد');
    });
    testWidgets('pending/rejected status includes reason ${brightness.name}',
        (tester) async {
      final profile = UserProfile(
          uid: 'a',
          name: 'مولد',
          generatorId: 'a',
          role: UserRole.admin,
          approvalStatus: ApprovalStatus.rejected,
          rejectionReason: 'القطاع غير متاح',
          createdAt: DateTime(2026));
      await boot(tester, const AccountStatusScreen(), brightness,
          auth: MultiAuthFixture(AuthState(
              user: PhoneUser('a'),
              profile: profile,
              loading: false,
              startupResolved: true)),
          tenant: const AsyncData(GeneratorAccount(
              id: 'a',
              name: 'مولد',
              sector: 'الرمال',
              status: GeneratorApproval.rejected)));
      expect(find.text('لم تتم الموافقة على الطلب'), findsOneWidget);
      expect(find.text('القطاع غير متاح'), findsOneWidget);
    });
  }
  for (final role in [UserRole.admin, UserRole.consumer]) {
    testWidgets('pending ${role.name} explains the correct reviewer',
        (tester) async {
      final profile = UserProfile(
          uid: 'pending',
          name: 'طلب',
          generatorId: 'a',
          role: role,
          approvalStatus: ApprovalStatus.pending,
          createdAt: DateTime(2026));
      await boot(tester, const AccountStatusScreen(), Brightness.light,
          auth: MultiAuthFixture(AuthState(
              user: PhoneUser('pending'),
              profile: profile,
              loading: false,
              startupResolved: true)),
          tenant: const AsyncData(a));
      expect(
          find.text(role == UserRole.admin
              ? 'طلب المولد قيد المراجعة من المشرف العام'
              : 'بانتظار موافقة صاحب المولد'),
          findsOneWidget);
    });
  }
  testWidgets('picker handles live removal of the selected sector safely',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('generatorDirectory').doc('a').set(a.directory());
    await db.collection('generatorDirectory').doc('b').set(b.directory());
    await boot(tester, const EnrollmentFormScreen(), Brightness.light, db: db);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الرمال').last);
    await tester.pumpAndSettle();
    await tapText(tester, 'مولد النور');
    await db
        .collection('generatorDirectory')
        .doc('a')
        .update({'subscriptionStatus': 'inactive'});
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('مولد الأمل'), findsOneWidget);
    expect(find.text('مولد النور'), findsNothing);
  });
  for (final state in ['empty', 'loading', 'error']) {
    testWidgets('picker and generator requests $state states', (tester) async {
      final AsyncValue<List<GeneratorAccount>> fixture = state == 'empty'
          ? const AsyncData([])
          : state == 'loading'
              ? const AsyncLoading()
              : AsyncError(StateError('offline'), StackTrace.empty);
      await boot(tester, const EnrollmentFormScreen(), Brightness.light,
          directory: fixture);
      if (state == 'empty') {
        expect(find.text('لا توجد مولدات متاحة تطابق البحث'), findsOneWidget);
      }
      if (state == 'loading') {
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      }
      if (state == 'error') {
        expect(find.text('تعذّر تحميل المولدات'), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await boot(tester, const GeneratorRequestsScreen(), Brightness.dark,
          requests: fixture);
      if (state == 'empty') {
        expect(find.text('لا توجد طلبات مولدات'), findsOneWidget);
      }
      if (state == 'loading') {
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      }
      if (state == 'error') {
        expect(find.text('تعذّر تحميل طلبات المولدات'), findsOneWidget);
      }
    });
  }
  testWidgets(
      'super-admin approval UI updates private and public records locally',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('sa').set({'role': 'super_admin'});
    await db.collection('users').doc('a').set(
        {'role': 'generator_owner', 'generatorId': 'a', 'status': 'pending'});
    await db.collection('generators').doc('a').set({
      'name': 'مولد',
      'sector': 'الرمال',
      'ownerUid': 'a',
      'status': 'pending',
      'subscriptionStatus': 'active'
    });
    final auth = MultiAuthFixture(AuthState(
        user: PhoneUser('sa'),
        profile: UserProfile(
            uid: 'sa',
            name: 'مشرف',
            role: UserRole.superAdmin,
            createdAt: DateTime(2026)),
        loading: false,
        startupResolved: true));
    await boot(tester, const GeneratorRequestsScreen(), Brightness.light,
        auth: auth, db: db);
    await tapText(tester, 'موافقة');
    expect(
        (await db.collection('generatorDirectory').doc('a').get())
            .data()!['status'],
        'approved');
    expect((await db.collection('users').doc('a').get()).data()!['status'],
        'approved');
    expect(find.text('مقبول'), findsOneWidget);
    await tapText(tester, 'تعليق المولد');
    expect(find.text('موقوف'), findsOneWidget);
    await tapText(tester, 'إعادة التفعيل');
    expect(find.text('مقبول'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(
        (await db.collection('generatorDirectory').doc('a').get())
            .data()!['subscriptionStatus'],
        'inactive');
  });
  test('enrollment/pending/suspended transitions are gated before role homes',
      () {
    final profile = UserProfile(
        uid: 'c',
        name: 'أحمد',
        generatorId: 'a',
        role: UserRole.consumer,
        createdAt: DateTime(2026));
    String? redirect(
            {UserProfile? p,
            bool registration = false,
            bool tenantLoading = false,
            bool available = true}) =>
        authRedirect(
            path: '/consumer',
            startupResolved: true,
            loading: false,
            loggedIn: true,
            profile: p,
            needsRegistration: registration,
            tenantLoading: tenantLoading,
            tenantAvailable: available);
    expect(redirect(registration: true), '/onboarding');
    expect(
        redirect(p: profile.copyWith(approvalStatus: ApprovalStatus.pending)),
        '/account-status');
    expect(redirect(p: profile, tenantLoading: true), '/splash');
    expect(redirect(p: profile, available: false), '/account-status');
    expect(redirect(p: profile), isNull);
  });
}
