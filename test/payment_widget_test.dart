import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:generator_portal/models/bill_model.dart';
import 'package:generator_portal/models/user_model.dart';
import 'package:generator_portal/providers/auth_provider.dart';
import 'package:generator_portal/providers/tenant_provider.dart';
import 'package:generator_portal/theme/portal_theme.dart';
import 'package:generator_portal/views/widgets/payment_form.dart';
import 'package:generator_portal/views/widgets/portal_keyboard.dart';
import 'package:generator_portal/views/screens/admin/subscriber_details_screen.dart';
import 'support/multi_auth_fixture.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('payment form to owner review ${brightness.name}', (t) async {
      final db = FakeFirebaseFirestore();
      for (final row in [('c', 'user'), ('o', 'generator_owner')]) {
        await db.collection('users').doc(row.$1).set({
          'name': row.$1,
          'role': row.$2,
          'status': 'approved',
          'subscriptionStatus': 'active',
          'generatorId': 'a'
        });
      }
      await db
          .collection('generators')
          .doc('a')
          .set({'status': 'approved', 'subscriptionStatus': 'active'});
      await db.collection('bills').doc('bill').set({
        'generatorId': 'a',
        'userId': 'c',
        'month': 'نوفمبر',
        'year': 2026,
        'amount': 100,
        'kwh': 50,
        'status': 'pending',
        'createdAt': 1
      });
      AuthState actor(String uid, UserRole role) => AuthState(
          user: PhoneUser(uid),
          profile: UserProfile(
              uid: uid,
              name: uid,
              role: role,
              generatorId: 'a',
              createdAt: DateTime(2026)),
          startupResolved: true,
          loading: false);
      final auth = MultiAuthFixture(actor('c', UserRole.consumer));
      t.view.physicalSize = const Size(430, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(ProviderScope(
          overrides: [
            firestoreProvider.overrideWithValue(db),
            authProvider.overrideWith((ref) => auth)
          ],
          child: MaterialApp(
              theme: buildPortalTheme(brightness),
              locale: const Locale('ar'),
              supportedLocales: const [Locale('ar')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate
              ],
              home: Builder(
                  builder: (context) => Scaffold(
                          body: Column(children: [
                        TextButton(
                            onPressed: () async {
                              final doc = await db
                                  .collection('bills')
                                  .doc('bill')
                                  .get();
                              if (context.mounted) {
                                showPortalFormSheet(
                                    context: context,
                                    builder: (_) => PaymentForm(
                                        bill:
                                            Bill.fromMap('bill', doc.data()!)));
                              }
                            },
                            child: const Text('فتح الدفع')),
                        TextButton(
                            onPressed: () async {
                              final doc = await db
                                  .collection('bills')
                                  .doc('bill')
                                  .get();
                              if (context.mounted) {
                                showPortalFormDialog(
                                    context: context,
                                    builder: (_) => ReceiptReviewDialog(
                                        bill: Bill.fromMap('bill', doc.data()!),
                                        subscriberName: 'مشترك'));
                              }
                            },
                            child: const Text('مراجعة'))
                      ]))))));
      await t.pumpAndSettle();
      await t.tap(find.text('فتح الدفع'));
      await t.pumpAndSettle();
      await t.enterText(
          find.byKey(const ValueKey('payment-reference')), 'BANK-001');
      await t.ensureVisible(find.text('إرسال للمراجعة'));
      await t.tap(find.text('إرسال للمراجعة'));
      await t.pumpAndSettle();
      expect((await db.collection('bills').doc('bill').get()).data()?['status'],
          'pendingReview');
      auth.replace(actor('o', UserRole.admin));
      await t.pump();
      await t.tap(find.text('مراجعة'));
      await t.pumpAndSettle();
      expect(find.text('BANK-001'), findsOneWidget);
      expect(find.text('نقداً'), findsOneWidget);
      await t.ensureVisible(find.text('قبول'));
      await t.tap(find.text('قبول'));
      await t.pumpAndSettle();
      expect((await db.collection('bills').doc('bill').get()).data()?['status'],
          'paid');
      expect((await db.collection('alerts').get()).docs.length, 1);
      expect(t.takeException(), isNull);
    });
  }
}
