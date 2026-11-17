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
      {String? name, String? address, String? phone}) async {
    saves++;
    await done.future;
    replace(state.copyWith(
        profile: state.profile!
            .copyWith(name: name, address: address, phone: phone)));
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
}
