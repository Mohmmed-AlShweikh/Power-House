import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generator_portal/features/metering/screens.dart';
import 'package:generator_portal/features/rounds/screens.dart';
import 'package:generator_portal/features/finance/screen.dart';
import 'package:generator_portal/features/finance/repository.dart';
import 'package:generator_portal/features/distribution/screens.dart';
import 'package:generator_portal/features/distribution/repository.dart';
import 'package:generator_portal/features/billing_shared/widgets.dart';
import 'package:generator_portal/views/widgets/portal_components.dart';
import 'package:generator_portal/models/generator_model.dart';
import 'package:generator_portal/models/user_model.dart';
import 'package:generator_portal/providers/auth_provider.dart';
import 'package:generator_portal/providers/tenant_provider.dart';
import 'package:generator_portal/services/tenant_store.dart';
import 'package:generator_portal/theme/portal_theme.dart';
import '../support/billing_fixture.dart';
import '../support/multi_auth_fixture.dart';

void main() {
  setUpAll(() async {
    for (final family in ['PortalArabic', 'PortalCurrency', 'MaterialIcons']) {
      final font = FontLoader(family);
      if (family == 'PortalArabic') {
        for (final w in ['Regular', 'SemiBold', 'Bold']) {
          font.addFont(rootBundle.load('assets/fonts/NotoSansArabic-$w.ttf'));
        }
      } else {
        font.addFont(rootBundle.load(family == 'PortalCurrency'
            ? 'assets/fonts/NotoSans-Regular.ttf'
            : 'fonts/MaterialIcons-Regular.otf'));
      }
      await font.load();
    }
  });
  for (final brightness in Brightness.values) {
    testWidgets('all added billing screens ${brightness.name}', (t) async {
      final f = BillingFixture();
      await f.seed();
      final rid = await f.closed();
      final store = TenantStore(f.db, () => 'o');
      await DistributionRepository(store).publish(rid);
      final finance = FinanceRepository(store);
      await finance.expense(
          amount: 2000,
          date: 1794700800000,
          category: 'fuel',
          note: 'ديزل',
          roundId: rid);
      await finance.rebuild();
      await f.db.collection('users').doc('r').set({
        'name': 'عامل العدادات',
        'role': 'meter_reader',
        'generatorId': 'g',
        'status': 'approved',
        'subscriptionStatus': 'active'
      });
      await f.db.collection('meterStaff').doc('r').set({
        'name': 'عامل العدادات',
        'generatorId': 'g',
        'active': true,
        'inviteCode': 'code'
      });
      await f.owner.assignReader('c', 'r');
      final open = await f.owner.openRound(DateTime.utc(2026, 11, 15));
      await f.owner.ownerReading(open, 'c', 40000);
      t.view.physicalSize = const Size(430, 1100);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final cases = <String, Widget>{
        'staff': const MeterStaffScreen(),
        'reader_join': const ReaderJoinScreen(),
        'rounds': const RoundsScreen(),
        'round_entry': RoundScreen(open),
        'statement': const CycleStatementScreen(),
        'finance': const FinanceScreen(),
        'distribution': const DistributionScreen(),
        'whatsapp': BillSharingScreen(rid),
        'reader': const MeterReaderScreen()
      };
      for (final e in cases.entries) {
        final role = e.key == 'reader' ? UserRole.meterReader : UserRole.admin,
            uid = e.key == 'reader' ? 'r' : 'o';
        final auth = MultiAuthFixture(AuthState(
            user: PhoneUser(uid),
            profile: UserProfile(
                uid: uid,
                name: 'صاحب المولد',
                generatorId: 'g',
                role: role,
                createdAt: DateTime(2026)),
            startupResolved: true,
            loading: false));
        await t.pumpWidget(ProviderScope(
            key: ValueKey(e.key),
            overrides: [
              firestoreProvider.overrideWithValue(f.db),
              authProvider.overrideWith((ref) => auth),
              tenantAccessProvider.overrideWithValue(const AsyncData(
                  GeneratorAccount(
                      id: 'g',
                      name: 'مولد',
                      sector: 'حي',
                      status: GeneratorApproval.approved)))
            ],
            child: MaterialApp(
                theme: buildPortalTheme(brightness),
                locale: const Locale('ar'),
                supportedLocales: const [Locale('ar')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                home: RepaintBoundary(
                    key: const ValueKey('capture'), child: e.value))));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: e.key);
        await expectLater(
            find.byKey(const ValueKey('capture')),
            matchesGoldenFile(
                '../../docs/screenshots-billing/${e.key}_${brightness.name}.png'));
      }
    });
  }
  testWidgets('shared billing form stays above keyboard', (t) async {
    t.view.physicalSize = const Size(430, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetViewInsets);
    await t.pumpWidget(MaterialApp(
        theme: buildPortalTheme(Brightness.light),
        home: Scaffold(
            body: Builder(
                builder: (c) => TextButton(
                    onPressed: () => featureForm(c, 'نموذج',
                        {'المبلغ': '', 'المرجع': '', 'الملاحظة': ''}),
                    child: const Text('فتح'))))));
    await t.tap(find.text('فتح'));
    await t.pumpAndSettle();
    await t.tap(find.byType(TextField).last);
    t.view.viewInsets = const FakeViewPadding(bottom: 300);
    await t.pumpAndSettle();
    expect(
        t.getRect(find.byType(TextField).last).bottom, lessThanOrEqualTo(500));
    await t.ensureVisible(find.text('حفظ'));
    expect(t.getRect(find.text('حفظ')).bottom, lessThanOrEqualTo(500));
  });
  for (final brightness in Brightness.values) {
    testWidgets('shared billing loading empty error states ${brightness.name}',
        (t) async {
      var retried = false;
      await t.pumpWidget(MaterialApp(
          theme: buildPortalTheme(brightness),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
              body: RepaintBoundary(
                  key: const ValueKey('feature-states'),
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                    FeatureData<int>(
                        value: const AsyncLoading(),
                        retry: () {},
                        builder: (_) => const SizedBox()),
                    FeatureData<int>(
                        value: AsyncError(StateError('test'), StackTrace.empty),
                        retry: () => retried = true,
                        builder: (_) => const SizedBox()),
                    FeatureData<int>(
                        value: const AsyncData(0),
                        retry: () {},
                        builder: (_) => const PortalEmptyState(
                            'لا توجد سجلات؛ أضف أول سجل'))
                  ])))));
      await t.pumpAndSettle();
      expect(find.byType(FeatureLoading), findsOneWidget);
      expect(find.text('لا توجد سجلات؛ أضف أول سجل'), findsOneWidget);
      await t.tap(find.text('إعادة المحاولة'));
      expect(retried, true);
      await expectLater(
          find.byKey(const ValueKey('feature-states')),
          matchesGoldenFile(
              '../../docs/screenshots-billing/states_${brightness.name}.png'));
    });
  }
}
