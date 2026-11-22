import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:generator_portal/providers/auth_provider.dart';
import 'package:generator_portal/services/credential_service.dart';
import 'package:generator_portal/views/screens/credential_screen.dart';
import 'package:generator_portal/theme/portal_theme.dart';
import 'support/credential_fakes.dart';
import 'support/multi_auth_fixture.dart';

class EmailFixture extends MultiAuthFixture {
  String? email, password;
  Completer<void>? loginGate;
  int reloads = 0, loginCalls = 0;
  String? loginError;
  @override
  Future<void> reloadProfile() async {
    reloads++;
  }

  @override
  Future<String?> login(String email, String password) async {
    loginCalls++;
    this.email = email;
    this.password = password;
    await loginGate?.future;
    return loginError ?? (password == 'wrong' ? genericAuthError : null);
  }
}

class ResumeCredentials extends FakeCredentials {
  int refreshes = 0;
  @override
  Future<void> refresh() async {
    refreshes++;
  }
}

void main() {
  Future<EmailFixture> boot(WidgetTester tester, CredentialMode mode,
      FakeCredentials service, Brightness brightness) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = EmailFixture();
    final router = GoRouter(initialLocation: '/test', routes: [
      GoRoute(path: '/test', builder: (_, __) => CredentialScreen(mode: mode)),
      GoRoute(
          path: '/forgot-password',
          builder: (_, __) =>
              const CredentialScreen(mode: CredentialMode.recover)),
      GoRoute(
          path: '/register',
          builder: (_, __) =>
              const CredentialScreen(mode: CredentialMode.create)),
      GoRoute(
          path: '/login',
          builder: (_, __) =>
              const CredentialScreen(mode: CredentialMode.login))
    ]);
    addTearDown(router.dispose);
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
    return auth;
  }

  Future<void> field(WidgetTester t, String key, String value) async {
    final f = find.byKey(ValueKey(key));
    await t.ensureVisible(f);
    await t.enterText(f, value);
  }

  Future<void> tap(WidgetTester t, String label) async {
    final f = find.text(label).last;
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  for (final passwordFirst in [false, true]) {
    testWidgets(
        'bulk autofill submits once after debounce (password first: $passwordFirst)',
        (t) async {
      final auth = await boot(
          t, CredentialMode.login, FakeCredentials(), Brightness.light);
      auth.loginGate = Completer<void>();
      if (passwordFirst) {
        await field(t, 'password', 'Strong123');
        await field(t, 'email', 'test@example.com');
      } else {
        await field(t, 'email', 'test@example.com');
        await field(t, 'password', 'Strong123');
      }
      await t.pump(const Duration(milliseconds: 399));
      expect(auth.loginCalls, 0);
      await t.pump(const Duration(milliseconds: 1));
      expect(auth.loginCalls, 1);
      expect(t.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNull);
      expect(
          find.descendant(
              of: find.byType(ElevatedButton),
              matching: find.byType(CircularProgressIndicator)),
          findsOneWidget);
      expect(
          t
              .widgetList<TextField>(find.byType(TextField))
              .every((f) => f.enabled == false),
          true);
      expect(t.testTextInput.isVisible, false);
      await t.pump(const Duration(seconds: 2));
      expect(auth.loginCalls, 1);
      auth.loginGate!.complete();
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 1));
      expect(auth.loginCalls, 1);
    });
  }

  testWidgets(
      'character typing never auto-submits; manual button starts immediately',
      (t) async {
    final auth =
        await boot(t, CredentialMode.login, FakeCredentials(), Brightness.dark);
    auth.loginGate = Completer<void>();
    await field(t, 'email', 'test@example.com');
    const password = 'Strong123';
    for (var i = 1; i <= password.length; i++) {
      await field(t, 'password', password.substring(0, i));
      await t.pump(const Duration(milliseconds: 500));
    }
    expect(auth.loginCalls, 0);
    final button = find.byType(ElevatedButton);
    await t.ensureVisible(button);
    await t.tap(button);
    await t.pump();
    expect(auth.loginCalls, 1);
    expect(t.widget<ElevatedButton>(button).onPressed, isNull);
    expect(
        find.descendant(
            of: button, matching: find.byType(CircularProgressIndicator)),
        findsOneWidget);
    expect(t.testTextInput.isVisible, false);
    auth.loginGate!.complete();
    await t.pumpAndSettle();
  });

  testWidgets(
      'failed autofill restores fields and never retries unchanged credentials',
      (t) async {
    final auth = await boot(
        t, CredentialMode.login, FakeCredentials(), Brightness.light);
    auth.loginError = genericAuthError;
    await field(t, 'email', 'test@example.com');
    await field(t, 'password', 'Strong123');
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(auth.loginCalls, 1);
    expect(find.text(genericAuthError), findsOneWidget);
    expect(
        t
            .widgetList<TextField>(find.byType(TextField))
            .every((f) => f.enabled == true),
        true);
    expect(t.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull);
    final fields = t.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.first.controller!.text, 'test@example.com');
    expect(fields.last.controller!.text, 'Strong123');
    await t.pump(const Duration(seconds: 3));
    // Some password managers may refill the same pair; that must not loop.
    await field(t, 'password', '');
    await field(t, 'password', 'Strong123');
    await t.pump(const Duration(seconds: 1));
    expect(auth.loginCalls, 1);
    await tap(t, 'تسجيل الدخول');
    expect(auth.loginCalls, 2);
    // Changing the filled credentials permits a new automatic attempt.
    await field(t, 'password', '');
    await field(t, 'password', 'Changed123');
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(auth.loginCalls, 3);
  });

  testWidgets(
      'editing a bulk fill cancels pending auto-login; leaving cancels debounce',
      (t) async {
    final auth = await boot(
        t, CredentialMode.login, FakeCredentials(), Brightness.light);
    await field(t, 'email', 'test@example.com');
    await field(t, 'password', 'Strong123');
    await t.pump(const Duration(milliseconds: 200));
    await field(t, 'password', 'Strong1234');
    await t.pump(const Duration(seconds: 1));
    expect(auth.loginCalls, 0);
    await field(t, 'password', '');
    await field(t, 'password', 'Strong123');
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 1));
    expect(auth.loginCalls, 0);
  });

  testWidgets(
      'resume reloads verification and resolves profile only when verified',
      (t) async {
    final service = ResumeCredentials()..verified = false;
    final auth =
        await boot(t, CredentialMode.verify, service, Brightness.light);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(service.refreshes, 1);
    expect(auth.reloads, 0);
    service.verified = true;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(service.refreshes, 2);
    expect(auth.reloads, 1);
  });

  testWidgets(
      'typing does not submit; keyboard go immediately disables login and shows progress',
      (t) async {
    final auth = await boot(
        t, CredentialMode.login, FakeCredentials(), Brightness.light);
    auth.loginGate = Completer<void>();
    await field(t, 'email', 'test@example.com');
    await field(t, 'password', 'Strong123');
    expect(auth.email, isNull);
    await t.testTextInput.receiveAction(TextInputAction.go);
    await t.pump();
    expect(auth.email, 'test@example.com');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(t.testTextInput.isVisible, false);
    expect(
        t
            .widgetList<TextField>(find.byType(TextField))
            .every((f) => f.enabled == false),
        true);
    auth.loginGate!.complete();
    await t.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await t.pump(const Duration(seconds: 1));
    expect(auth.loginCalls, 1);
  });

  for (final brightness in Brightness.values) {
    testWidgets('email login and generic failure ${brightness.name}',
        (t) async {
      final auth =
          await boot(t, CredentialMode.login, FakeCredentials(), brightness);
      await field(t, 'email', 'test@example.com');
      await field(t, 'password', 'wrong');
      await tap(t, 'تسجيل الدخول');
      expect(auth.email, 'test@example.com');
      expect(find.text(genericAuthError), findsOneWidget);
      expect(find.text('الدخول برقم الهاتف'), findsNothing);
    });
    testWidgets('registration password rules and both roles ${brightness.name}',
        (t) async {
      final service = FakeCredentials();
      await boot(t, CredentialMode.create, service, brightness);
      await field(t, 'email', 'new@example.com');
      await field(t, 'password', 'weak');
      await field(t, 'password-confirm', 'weak');
      await tap(t, 'إنشاء الحساب وإرسال التحقق');
      expect(service.submittedEmail, isNull);
      await field(t, 'password', 'Strong123');
      await field(t, 'password-confirm', 'Strong123');
      await tap(t, 'صاحب مولد');
      await tap(t, 'إنشاء الحساب وإرسال التحقق');
      expect(service.submittedEmail, 'new@example.com');
    });
    testWidgets(
        'password reset by email does not disclose existence ${brightness.name}',
        (t) async {
      final service = FakeCredentials();
      await boot(t, CredentialMode.login, service, brightness);
      await tap(t, 'نسيت كلمة المرور؟');
      await field(t, 'email', 'test@example.com');
      await tap(t, 'إرسال رابط الاستعادة');
      expect(service.resetEmail, 'test@example.com');
      expect(find.textContaining('إذا كان البريد مسجلاً'), findsOneWidget);
    });
    testWidgets('unverified email offers reload and resend ${brightness.name}',
        (t) async {
      final service = FakeCredentials()..verified = false;
      await boot(t, CredentialMode.verify, service, brightness);
      await tap(t, 'تحققت من البريد');
      expect(find.textContaining('لم يتم التحقق بعد'), findsOneWidget);
      await tap(t, 'إعادة إرسال رسالة التحقق');
      expect(service.verificationSent, true);
    });
  }
}
