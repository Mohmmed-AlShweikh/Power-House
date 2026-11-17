import 'package:generator_portal/views/widgets/portal_auth_page.dart';
import 'package:generator_portal/services/contact_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:generator_portal/providers/theme_provider.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:generator_portal/providers/auth_provider.dart';
import 'package:generator_portal/providers/tenant_provider.dart';
import 'package:generator_portal/models/user_model.dart';
import 'package:generator_portal/theme/portal_theme.dart';
import 'package:generator_portal/views/widgets/profile_edit_sheet.dart';
import 'package:generator_portal/views/widgets/portal_keyboard.dart';
import 'support/multi_auth_fixture.dart';

class EditAuth extends MultiAuthFixture {
  final done = Completer<void>();
  int saves = 0;
  EditAuth()
      : super(AuthState(
            user: PhoneUser('c'),
            profile: UserProfile(
                uid: 'c',
                name: 'اسم',
                address: 'قديم',
                phone: '0591234567',
                generatorId: 'g',
                role: UserRole.consumer,
                createdAt: DateTime(2026)),
            startupResolved: true,
            loading: false));
  @override
  Future<void> updateProfile(
      {String? name, String? address, String? phone, String? idNumber}) async {
    saves++;
    await done.future;
    replace(state.copyWith(
        profile: state.profile!.copyWith(
            name: name, address: address, phone: phone, idNumber: idNumber)));
  }
}

void main() {
  test('contact-only profile event does not restart generator authorization',
      () async {
    final db = FakeFirebaseFirestore();
    await db
        .collection('generators')
        .doc('g')
        .set({'status': 'approved', 'subscriptionStatus': 'active'});
    final auth = EditAuth();
    final c = ProviderContainer(overrides: [
      authProvider.overrideWith((_) => auth),
      firestoreProvider.overrideWithValue(db)
    ]);
    addTearDown(c.dispose);
    final events = <AsyncValue>[];
    c.listen(currentGeneratorAccountProvider, (_, next) => events.add(next),
        fireImmediately: true);
    await c.read(currentGeneratorAccountProvider.future);
    events.clear();
    auth.replace(auth.state
        .copyWith(profile: auth.state.profile!.copyWith(address: 'جديد')));
    await Future<void>.delayed(Duration.zero);
    expect(events.any((s) => s.isLoading), false);
    expect(
        c.read(currentGeneratorAccountProvider).valueOrNull?.available, true);
  });
  for (final dismiss in [false, true]) {
    testWidgets(
        'profile save completes once; dismissed=$dismiss never pops the page',
        (t) async {
      final auth = EditAuth();
      await t.pumpWidget(ProviderScope(
          overrides: [authProvider.overrideWith((_) => auth)],
          child: MaterialApp(
              theme: buildPortalTheme(Brightness.light),
              home: Scaffold(
                  body: Builder(
                      builder: (c) => TextButton(
                          onPressed: () => showPortalFormSheet(
                              context: c,
                              builder: (_) => const ProfileEditSheet()),
                          child: const Text('الملف')))))));
      await t.tap(find.text('الملف'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).at(1), 'عنوان جديد');
      await t.tap(find.text('حفظ التغييرات'));
      await t.pump();
      expect(find.text('جارٍ الحفظ…'), findsOneWidget);
      expect(auth.saves, 1);
      if (dismiss) {
        final ctx = t.element(find.byType(ProfileEditSheet));
        Navigator.of(ctx).pop();
        await t.pumpAndSettle();
      }
      auth.done.complete();
      await t.pumpAndSettle();
      expect(find.text('الملف'), findsOneWidget);
      expect(find.byType(ProfileEditSheet), findsNothing);
      expect(t.takeException(), isNull);
      if (!dismiss) expect(find.text('تم حفظ البيانات ✓'), findsOneWidget);
    });
  }
  test(
      'system-dark first tap goes light and startup load cannot overwrite user choice',
      () async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeNotifier();
    await Future<void>.delayed(Duration.zero);
    await theme.toggle(visibleBrightness: Brightness.dark);
    expect(theme.state, ThemeMode.light);
    theme.dispose();
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    final racing = ThemeNotifier();
    await racing.toggle(visibleBrightness: Brightness.dark);
    await Future<void>.delayed(Duration.zero);
    expect(racing.state, ThemeMode.light);
    racing.dispose();
  });

  test(
      'contact normalizes Arabic digits and Palestinian international mobile prefixes',
      () {
    for (final value in [
      '٠٥٩١٢٣٤٥٦٧',
      '۰۵۹۱۲۳۴۵۶۷',
      '+970 59 123 4567',
      '00972-59-1234567'
    ]) {
      expect(normalizeMobile(value), '0591234567');
      expect(palestinianMobile(value), true);
    }
    expect(contactError('', '', requiredPhone: true), isNotNull);
    expect(contactError('059123456', '123456789'), isNotNull);
    expect(contactError('+972541234567', ''), isNotNull);
    expect(contactError('0591234567', '١٢٣٤٥٦٧٨٩'), isNull);
  });
  testWidgets(
      'auth group centers on tablet and scrolls to focused field with keyboard',
      (t) async {
    t.view.physicalSize = const Size(1000, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetViewInsets);
    await t.pumpWidget(MaterialApp(
        theme: buildPortalTheme(Brightness.light),
        home: PortalAuthPage(title: 'تسجيل الدخول', children: const [
          TextField(decoration: InputDecoration(labelText: 'البريد')),
          TextField(decoration: InputDecoration(labelText: 'كلمة المرور'))
        ])));
    await t.pumpAndSettle();
    final group = t.getRect(find.byKey(const ValueKey('auth-centered-group')));
    expect(group.width, lessThanOrEqualTo(420));
    expect(group.center.dx, closeTo(500, 1));
    expect(group.center.dy, closeTo(500, 2));
    await t.tap(find.byType(TextField).last);
    t.view.viewInsets = const FakeViewPadding(bottom: 650);
    await t.pumpAndSettle();
    await t.ensureVisible(find.byType(TextField).last);
    expect(
        t.getRect(find.byType(TextField).last).bottom, lessThanOrEqualTo(350));
    expect(t.takeException(), isNull);
  });
}
