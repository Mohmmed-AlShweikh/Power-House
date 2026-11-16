import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:generator_portal/models/user_model.dart';
import 'package:generator_portal/providers/auth_provider.dart';
import 'package:generator_portal/services/credential_service.dart';
import 'package:generator_portal/theme/portal_theme.dart';
import 'package:generator_portal/views/screens/credential_screen.dart';
import 'package:generator_portal/views/screens/login_screen.dart';
import 'support/credential_fakes.dart';
import 'support/multi_auth_fixture.dart';

void main() {
  Future<void> boot(WidgetTester tester, CredentialMode mode,
      FakeCredentials service, Brightness brightness) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(initialLocation: '/test', routes: [
      GoRoute(path: '/test', builder: (_, __) => CredentialScreen(mode: mode)),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: '/consumer',
          builder: (_, __) => const Text('same account home')),
      GoRoute(
          path: '/onboarding',
          builder: (_, __) => const Text('complete registration')),
    ]);
    addTearDown(router.dispose);
    final auth = MultiAuthFixture(AuthState(
        user: PhoneUser('same'),
        profile: UserProfile(
            uid: 'same',
            name: 'مشترك',
            phone: service.phone,
            idNumber: '123456789',
            role: UserRole.consumer,
            createdAt: DateTime(2026)),
        loading: false,
        startupResolved: true));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => auth),
          credentialServiceProvider.overrideWithValue(service)
        ],
        child: MaterialApp.router(
            routerConfig: router,
            theme: buildPortalTheme(brightness),
            locale: const Locale('ar'),
            supportedLocales: const [
              Locale('ar')
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate
            ])));
    await tester.pumpAndSettle();
  }

  Future<void> field(WidgetTester tester, String key, String value) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.enterText(finder, value);
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final f = find.text(label);
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets(
        'forgot ID mismatch stays generic, never shows new-password form ${brightness.name}',
        (tester) async {
      final service = FakeCredentials()..matches = false;
      await boot(tester, CredentialMode.recover, service, brightness);
      await field(tester, 'credential-id', '987654321');
      await field(tester, 'credential-phone', service.phone);
      await tap(tester, 'إرسال رمز التحقق');
      await field(tester, 'credential-otp', '123456');
      await tap(tester, 'تحقق من الرمز');
      expect(find.text(genericAuthError), findsOneWidget);
      expect(find.byKey(const ValueKey('credential-password')), findsNothing);
      expect(service.reset, false);
    });
    testWidgets(
        'OTP recovery validates live password rules and succeeds ${brightness.name}',
        (tester) async {
      final service = FakeCredentials();
      await boot(tester, CredentialMode.recover, service, brightness);
      await field(tester, 'credential-id', '123456789');
      await field(tester, 'credential-phone', service.phone);
      await tap(tester, 'إرسال رمز التحقق');
      await field(tester, 'credential-otp', '123456');
      await tap(tester, 'تحقق من الرمز');
      expect(service.verifiedOperation, PhoneOperation.signIn);
      await field(tester, 'credential-password', 'weak');
      await field(tester, 'credential-confirm', 'weak');
      await tap(tester, 'حفظ كلمة المرور');
      expect(service.reset, false);
      await field(tester, 'credential-password', 'Strong123');
      await field(tester, 'credential-confirm', 'Strong123');
      await tap(tester, 'حفظ كلمة المرور');
      expect(service.reset, true);
      expect(
          find.text('تم تغيير كلمة المرور. سجّل الدخول بكلمة المرور الجديدة.'),
          findsOneWidget);
    });
    testWidgets(
        'existing phone account links missing ID, duplicate is rejected ${brightness.name}',
        (tester) async {
      final service = FakeCredentials()
        ..hasPassword = false
        ..duplicate = true;
      await boot(tester, CredentialMode.complete, service, brightness);
      await field(tester, 'credential-password', 'Strong123');
      await field(tester, 'credential-confirm', 'Strong123');
      await tap(tester, 'حفظ ومتابعة');
      expect(find.text(genericAuthError), findsOneWidget);
      expect(service.linkedId, isNull);
      service.duplicate = false;
      await tap(tester, 'حفظ ومتابعة');
      expect(service.linkedId, '123456789');
      expect(find.text('same account home'), findsOneWidget);
    });
    testWidgets(
        'ID-first registration verifies phone before completing registration ${brightness.name}',
        (tester) async {
      final service = FakeCredentials()
        ..hasPhone = false
        ..phone = '';
      await boot(tester, CredentialMode.create, service, brightness);
      await field(tester, 'credential-id', '123456789');
      await field(tester, 'credential-phone', '+970591234567');
      await field(tester, 'credential-password', 'Strong123');
      await field(tester, 'credential-confirm', 'Strong123');
      await tap(tester, 'إرسال رمز التحقق');
      expect(service.createdId, '123456789');
      await field(tester, 'credential-otp', '123456');
      await tap(tester, 'تحقق من الرمز');
      expect(service.verifiedOperation, PhoneOperation.link);
      expect(find.text('complete registration'), findsOneWidget);
    });
  }
}
