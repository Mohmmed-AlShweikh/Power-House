import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:generator_portal/models/user_model.dart';
import 'package:generator_portal/providers/auth_provider.dart';
import 'package:generator_portal/providers/tenant_provider.dart';
import 'package:generator_portal/theme/portal_theme.dart';
import 'package:generator_portal/features/billing_settings/models.dart';
import 'package:generator_portal/features/billing_settings/providers.dart';
import 'package:generator_portal/features/billing_settings/screen.dart';
import '../support/multi_auth_fixture.dart';

void main() {
  setUpAll(() async {
    for (final family in ['PortalArabic', 'PortalCurrency', 'MaterialIcons']) {
      final loader = FontLoader(family);
      if (family == 'PortalArabic') {
        for (final weight in ['Regular', 'SemiBold', 'Bold']) {
          loader.addFont(
              rootBundle.load('assets/fonts/NotoSansArabic-$weight.ttf'));
        }
      } else {
        loader.addFont(rootBundle.load(family == 'PortalCurrency'
            ? 'assets/fonts/NotoSans-Regular.ttf'
            : 'fonts/MaterialIcons-Regular.otf'));
      }
      await loader.load();
    }
  });
  for (final brightness in Brightness.values) {
    testWidgets('owner saves future billing settings ${brightness.name}',
        (t) async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc('o').set({
        'role': 'generator_owner',
        'status': 'approved',
        'generatorId': 'a'
      });
      await db
          .collection('generators')
          .doc('a')
          .set({'status': 'approved', 'subscriptionStatus': 'active'});
      final auth = MultiAuthFixture(AuthState(
          user: PhoneUser('o'),
          profile: UserProfile(
              uid: 'o',
              name: 'مالك',
              role: UserRole.admin,
              generatorId: 'a',
              createdAt: DateTime(2026)),
          startupResolved: true,
          loading: false));
      t.view.physicalSize = const Size(430, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(ProviderScope(
          overrides: [
            firestoreProvider.overrideWithValue(db),
            authProvider.overrideWith((ref) => auth),
            billingSettingsProvider
                .overrideWith((ref) => Stream.value(const BillingSettings()))
          ],
          child: MaterialApp(
              theme: buildPortalTheme(brightness),
              locale: const Locale('ar'),
              supportedLocales: const [Locale('ar')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: const RepaintBoundary(
                  key: ValueKey('billing-settings-shot'),
                  child: BillingSettingsScreen()))));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).at(0), '28.00');
      await t.enterText(find.byType(TextField).at(2), '1.500');
      await t.ensureVisible(find.text('حفظ الإعدادات'));
      await t.tap(find.text('حفظ الإعدادات'));
      await t.pumpAndSettle();
      final d = (await db.collection('billingSettings').doc('a').get()).data()!;
      expect(d['priceAgorot'], 2800);
      expect(d['minimumUnitsMilli'], 1500);
      expect(find.text('تم الحفظ؛ الفواتير السابقة لا تتغير'), findsOneWidget);
      await expectLater(
          find.byKey(const ValueKey('billing-settings-shot')),
          matchesGoldenFile(
              '../../docs/screenshots-billing/settings_${brightness.name}.png'));
    });
  }
}
