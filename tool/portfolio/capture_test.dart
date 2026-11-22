// Presentation-only fake data. No Firebase initialization, remote calls or app changes.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:generator_portal/models/user_model.dart';
import 'package:generator_portal/models/bill_model.dart';
import 'package:generator_portal/models/alert_model.dart';
import 'package:generator_portal/models/complaint_model.dart';
import 'package:generator_portal/models/generator_model.dart';
import 'package:generator_portal/providers/auth_provider.dart';
import 'package:generator_portal/providers/tenant_provider.dart';
import 'package:generator_portal/providers/data_provider.dart';
import 'package:generator_portal/theme/portal_theme.dart';
import 'package:generator_portal/theme/portal_tokens.dart';
import 'package:generator_portal/services/tenant_store.dart';
import 'package:generator_portal/features/billing_settings/models.dart';
import 'package:generator_portal/features/rounds/screens.dart';
import 'package:generator_portal/features/finance/repository.dart';
import 'package:generator_portal/features/finance/screen.dart';
import 'package:generator_portal/features/distribution/repository.dart';
import 'package:generator_portal/features/metering/screens.dart';
import 'package:generator_portal/views/screens/admin/admin_screen.dart';
import 'package:generator_portal/views/screens/consumer/consumer_shell.dart';
import '../../test/support/billing_fixture.dart';
import '../../test/support/multi_auth_fixture.dart';

const names = [
  'أحمد سامي',
  'سارة عمر',
  'محمود حسن',
  'نور علي',
  'ليان خالد',
  'عمر يوسف',
  'هبة كريم',
  'خالد ناصر'
];
UserProfile demoProfile(UserRole role, {String uid = ''}) => UserProfile(
    uid: uid,
    name: role == UserRole.admin
        ? 'مولد حي النور'
        : role == UserRole.meterReader
            ? 'محمود حسن'
            : 'أحمد سامي',
    generatorId: 'g',
    phone: '0590000000',
    address: 'غزة، حي النور',
    role: role,
    approvalStatus: ApprovalStatus.approved,
    ampereLimit: 10,
    createdAt: DateTime(2026, 1));

void main() {
  setUpAll(() async {
    // This is a Flutter test driver, kept outside test/ to avoid rewriting
    // portfolio exports during the regular regression suite.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
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
  testWidgets('export real app screens using isolated fictional portfolio data',
      (t) async {
    t.view.physicalSize = const Size(430, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    Future<void> capture(String name, Widget page, List<Override> overrides,
        Brightness brightness) async {
      await t.pumpWidget(ProviderScope(
          key: ValueKey(name),
          overrides: overrides,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildPortalTheme(brightness),
              locale: const Locale('ar'),
              supportedLocales: const [Locale('ar')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: RepaintBoundary(
                  key: const ValueKey('capture'), child: page))));
      await t.runAsync(() async {
        final context = t.element(find.byType(MaterialApp));
        for (final asset in ['mark-primary-384.png', 'mark-reversed-384.png']) {
          await precacheImage(
              AssetImage('assets/brand/approved-a/$asset'), context);
        }
      });
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: name);
      final boundary = t.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('capture')));
      await t.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('docs/portfolio/media/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    final now = DateTime(2026, 11, 15, 9);
    final bills = [
      for (var i = 0; i < 8; i++)
        Bill(
            id: 'demo-$i',
            userId: 'demo-$i',
            month: 'نوفمبر',
            year: 2026,
            amount: 196 + i * 14,
            kwh: 70 + i * 5,
            status: i < 5 ? BillStatus.paid : BillStatus.pending,
            createdAt: now)
    ];
    final users = [
      for (var i = 0; i < 8; i++)
        UserProfile(
            uid: 'demo-$i',
            name: names[i],
            address: 'حي النور — شارع ${i + 1}',
            role: UserRole.consumer,
            approvalStatus: ApprovalStatus.approved,
            createdAt: DateTime(2026, 1))
    ];
    for (final brightness in Brightness.values) {
      for (final role in [UserRole.consumer, UserRole.admin]) {
        final auth = MultiAuthFixture(AuthState(
            profile: demoProfile(role), loading: false, startupResolved: true));
        await capture(
            '${role == UserRole.admin ? 'owner' : 'consumer'}_${brightness.name}',
            role == UserRole.admin
                ? const AdminScreen()
                : const ConsumerShell(),
            [
              authProvider.overrideWith((ref) => auth),
              generatorProvider.overrideWith((ref) => Stream.value(
                  GeneratorState(
                      isOn: true,
                      pricePerKwh: 2.8,
                      lastChanged: now.subtract(const Duration(hours: 2)),
                      scheduledOnAt: DateTime(2026, 11, 15, 8),
                      scheduledOffAt: DateTime(2026, 11, 15, 20)))),
              billsProvider('').overrideWith((ref) => Stream.value([
                    bills[0],
                    Bill(
                        id: 'oct',
                        userId: '',
                        month: 'أكتوبر',
                        year: 2026,
                        amount: 182,
                        kwh: 65,
                        status: BillStatus.paid,
                        createdAt: DateTime(2026, 10, 25))
                  ])),
              allBillsProvider.overrideWith((ref) => Stream.value(bills)),
              subscribersProvider.overrideWith((ref) => Stream.value(users)),
              consumerComplaintsProvider('')
                  .overrideWith((ref) => Stream.value(<Complaint>[])),
              complaintsProvider
                  .overrideWith((ref) => Stream.value(<Complaint>[])),
              pendingUsersProvider
                  .overrideWith((ref) => Stream.value(<UserProfile>[])),
              alertsProvider('').overrideWith((ref) => Stream.value([
                    AppAlert(
                        id: 'demo',
                        title: 'فاتورة نوفمبر جاهزة',
                        body: 'يمكنك مراجعة الفاتورة وتسجيل بيانات الدفع.',
                        type: AlertType.newBill,
                        createdAt: now.subtract(const Duration(hours: 1)),
                        read: false)
                  ])),
              consumptionProvider('').overrideWith((ref) => Stream.value(
                  const ConsumptionData(monthlyUsage: 70, dailyUsage: 2.3))),
              subscribersMapProvider.overrideWith((ref) => Stream.value(
                  {for (var i = 0; i < 8; i++) 'demo-$i': names[i]})),
              monthlyBillStatsProvider.overrideWith((ref) =>
                  const MonthlyBillStats(
                      unpaidCount: 3,
                      unpaidAmount: 840,
                      paidCount: 5,
                      paidAmount: 1120)),
              recentActivitiesProvider.overrideWith((ref) => [
                    ActivityItem(
                        name: 'سارة عمر',
                        action: 'اعتماد دفعة نوفمبر',
                        createdAt: now,
                        color: PortalTokens.primary)
                  ]),
            ],
            brightness);
      }
    }
    final f = BillingFixture();
    await f.seed();
    await f.db.collection('billingSettings').doc('g').set(
        const BillingSettings(priceAgorot: 280, minimumUnitsMilli: 1500)
            .toMap());
    for (var i = 0; i < 8; i++) {
      await f.db.collection('users').doc('demo-$i').set({
        'name': names[i],
        'role': 'user',
        'status': 'approved',
        'subscriptionStatus': 'active',
        'generatorId': 'g'
      });
      await f.owner.addSubscriber(
          name: names[i],
          phone: '',
          address: 'حي النور — شارع ${i + 1}',
          number: 'N-${101 + i}',
          startingMilli: 100000 + i * 20000,
          userId: 'demo-$i');
    }
    final closed = await f.owner.openRound(DateTime(2026, 11, 5));
    for (var i = 0; i < 8; i++) {
      await f.owner
          .ownerReading(closed, 'demo-$i', 125000 + i * 20000 + i * 1500);
    }
    await f.owner.closeRound(closed);
    await DistributionRepository(TenantStore(f.db, () => 'o')).publish(closed);
    final invoices = await f.db.collection('cycleBills').get();
    for (var i = 0; i < 6; i++) {
      final bill = invoices.docs[i];
      await f.owner.submitPayment(bill.id,
          amount: i == 5
              ? (bill.data()['amountAgorot'] as int) ~/ 2
              : bill.data()['amountAgorot'],
          date: DateTime(2026, 11, 8).millisecondsSinceEpoch,
          reference: 'DEMO-${101 + i}',
          method: 'cash',
          ownerEntry: true);
      await f.owner.reviewPayment('${bill.id}_1', true);
    }
    final finance = FinanceRepository(TenantStore(f.db, () => 'o'));
    await finance.expense(
        amount: 12000,
        date: DateTime(2026, 11, 6).millisecondsSinceEpoch,
        category: 'fuel',
        note: 'وقود الجولة');
    await finance.expense(
        amount: 3500,
        date: DateTime(2026, 11, 7).millisecondsSinceEpoch,
        category: 'maintenance',
        note: 'صيانة دورية');
    await finance.rebuild();
    await f.db.collection('users').doc('r').set({
      'name': 'محمود حسن',
      'role': 'meter_reader',
      'status': 'approved',
      'subscriptionStatus': 'active',
      'generatorId': 'g'
    });
    await f.db.collection('meterStaff').doc('r').set({
      'name': 'محمود حسن',
      'generatorId': 'g',
      'active': true,
      'inviteCode': 'DEMO'
    });
    for (var i = 0; i < 4; i++) {
      await f.owner.assignReader('demo-$i', 'r');
    }
    final open = await f.owner.openRound(DateTime(2026, 11, 15));
    await f.owner.ownerReading(open, 'demo-0', 151000);
    for (final brightness in Brightness.values) {
      for (final entry in <String, Widget>{
        'finance': const FinanceScreen(),
        'rounds': const RoundsScreen(),
        'readings': RoundScreen(open),
        'reader': const MeterReaderScreen(),
        'statement': const CycleStatementScreen()
      }.entries) {
        final reader = entry.key == 'reader',
            uid = reader ? 'r' : 'o',
            role = reader ? UserRole.meterReader : UserRole.admin;
        await capture(
            '${entry.key}_${brightness.name}',
            entry.value,
            [
              firestoreProvider.overrideWithValue(f.db),
              authProvider.overrideWith((ref) => MultiAuthFixture(AuthState(
                  user: PhoneUser(uid),
                  profile: demoProfile(role, uid: uid),
                  loading: false,
                  startupResolved: true))),
              tenantAccessProvider.overrideWith((ref) => const AsyncData(
                  GeneratorAccount(
                      id: 'g',
                      name: 'مولد حي النور',
                      sector: 'غزة، حي النور',
                      ownerUid: 'o',
                      status: GeneratorApproval.approved,
                      subscriptionStatus: 'active')))
            ],
            brightness);
      }
    }
  });
}
