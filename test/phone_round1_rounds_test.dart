import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generator_portal/features/rounds/overview.dart';
import 'package:generator_portal/features/rounds/repository.dart';
import 'package:generator_portal/models/generator_model.dart';
import 'package:generator_portal/models/user_model.dart';
import 'package:generator_portal/providers/auth_provider.dart';
import 'package:generator_portal/providers/tenant_provider.dart';
import 'package:generator_portal/services/tenant_store.dart';
import 'package:generator_portal/theme/portal_theme.dart';
import 'support/billing_fixture.dart';
import 'support/multi_auth_fixture.dart';

class InterruptLink extends RoundsRepository {
  InterruptLink(super.store);
  @override
  Future<void> repairLinks(String sid) async =>
      throw StateError('connection interrupted');
}

void main() {
  test(
      'pending linking is explicit and repair clears it without changing balances',
      () async {
    final f = BillingFixture();
    await f.seed();
    final sid = await f.owner.addSubscriber(
        name: 'اسم', phone: '', address: 'حي', number: '1', startingMilli: 0);
    await expectLater(
        InterruptLink(TenantStore(f.db, () => 'o')).linkAccount(sid, 'c'),
        throwsStateError);
    final sub = f.db.collection('billingSubscribers').doc(sid);
    expect((await sub.get()).data()!['linkPending'], true);
    final balance =
        (await f.db.collection('accountBalances').doc(sid).get()).data();
    await f.owner.repairLinks(sid);
    expect((await sub.get()).data()!['linkPending'], false);
    await f.owner.editSubscriber(sid,
        name: 'جديد', phone: '٠٥٩١٢٣٤٥٦٧', address: 'حي جديد', number: '2');
    expect((await sub.get()).data()!['previousMilli'], 0);
    expect((await f.db.collection('accountBalances').doc(sid).get()).data(),
        balance);
  });
  for (final state in ['manual', 'pending', 'linked']) {
    testWidgets('subscriber menu has one correct link action: $state',
        (t) async {
      final f = BillingFixture();
      await f.seed();
      final auth = MultiAuthFixture(AuthState(
          user: PhoneUser('o'),
          profile: UserProfile(
              uid: 'o',
              name: 'مالك',
              generatorId: 'g',
              role: UserRole.admin,
              createdAt: DateTime(2026)),
          loading: false,
          startupResolved: true));
      await t.pumpWidget(ProviderScope(
          overrides: [
            firestoreProvider.overrideWithValue(f.db),
            authProvider.overrideWith((_) => auth),
            tenantAccessProvider.overrideWithValue(const AsyncData(
                GeneratorAccount(
                    id: 'g',
                    name: 'مولد',
                    sector: 'حي',
                    status: GeneratorApproval.approved)))
          ],
          child: MaterialApp(
              theme: buildPortalTheme(Brightness.light),
              home: Scaffold(
                  body: SubscriberOverviewCard(id: 's', data: {
                'name': 'اسم',
                'number': '1',
                'address': 'حي',
                'phone': '',
                'previousMilli': 20000,
                'userId': state == 'manual' ? '' : 'c',
                'linkPending': state == 'pending',
                'readerUid': 'o'
              })))));
      await t.pumpAndSettle();
      await t.tap(find.byType(PopupMenuButton<String>));
      await t.pumpAndSettle();
      expect(find.text('ربط بحساب'),
          state == 'manual' ? findsOneWidget : findsNothing);
      expect(find.text('إكمال الربط'),
          state == 'pending' ? findsOneWidget : findsNothing);
      expect(find.text('إسناد قارئ'), findsOneWidget);
      expect(find.text('تعديل'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
