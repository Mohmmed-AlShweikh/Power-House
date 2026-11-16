import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:generator_portal/main.dart';
import 'package:generator_portal/config/router.dart';
import 'package:generator_portal/config/auth_redirect.dart';
import 'package:generator_portal/providers/auth_provider.dart';
import 'package:generator_portal/models/user_model.dart';
import 'support/multi_auth_fixture.dart';
import 'package:generator_portal/models/generator_model.dart';
import 'package:generator_portal/providers/tenant_provider.dart';
import 'package:generator_portal/services/cached_profile.dart';
import 'package:generator_portal/services/startup_splash.dart';
import 'package:generator_portal/services/tenant_store.dart';
import 'package:generator_portal/views/screens/auth_loading_screen.dart';

void main() {
  testWidgets(
      'native splash releases only after a resolved destination frame, once',
      (tester) async {
    var releases = 0;
    final controller = NativeSplashController.testing(() => releases++);
    final router = GoRouter(initialLocation: '/splash', routes: [
      GoRoute(path: '/splash', builder: (_, __) => const AuthLoadingScreen()),
      GoRoute(path: '/home', builder: (_, __) => const Text('home')),
    ]);
    addTearDown(router.dispose);
    Future<void> mount(bool ready) => tester.pumpWidget(MaterialApp.router(
        routerConfig: router,
        builder: (_, child) => NativeSplashRelease(
            router: router,
            controller: controller,
            ready: ready,
            child: child!)));
    await mount(false);
    await tester.pump(const Duration(milliseconds: 900));
    expect(releases, 0);
    await mount(true);
    await tester.pump();
    expect(
        releases, 0); // Auth ready is insufficient while the splash is routed.
    router.go('/home');
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(releases, 1);
    await mount(true);
    expect(releases, 1);
  });

  testWidgets('fallback logo stays fixed and no indicator appears before 800ms',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthLoadingScreen()));
    final logo = find.byKey(const ValueKey('continuous-splash-logo'));
    final rect = tester.getRect(logo);
    expect(rect.width, 288);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 799));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.getRect(logo), rect);
    await tester.pumpWidget(const SizedBox());
  });

  for (final role in UserRole.values) {
    testWidgets(
        'fast login routes directly by $role without an intermediate Flutter splash',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final db = FakeFirebaseFirestore();
      final auth = MultiAuthFixture();
      var releases = 0;
      final native = NativeSplashController.testing(() => releases++);
      final container = ProviderContainer(overrides: [
        authProvider.overrideWith((ref) => auth),
        firestoreProvider.overrideWithValue(db),
        tenantAccessProvider.overrideWithValue(const AsyncData(GeneratorAccount(
            id: 'g',
            name: 'مولد',
            sector: 'الرمال',
            status: GeneratorApproval.approved))),
        nativeSplashProvider.overrideWithValue(native),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container, child: const GeneratorPortalApp()));
      await tester.pumpAndSettle();
      expect(
          container
              .read(routerProvider)
              .routeInformationProvider
              .value
              .uri
              .path,
          '/login');
      expect(releases, 1);
      auth.replace(AuthState(
          user: PhoneUser('u'), loading: true, startupResolved: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AuthLoadingScreen), findsNothing);
      auth.replace(AuthState(
          user: PhoneUser('u'),
          startupResolved: true,
          loading: false,
          profile: UserProfile(
              uid: '',
              name: 'تجربة',
              role: role,
              generatorId: 'g',
              createdAt: DateTime(2026))));
      await tester.pumpAndSettle();
      expect(
          container
              .read(routerProvider)
              .routeInformationProvider
              .value
              .uri
              .path,
          switch (role) {
            UserRole.consumer => '/consumer',
            UserRole.admin => '/admin',
            UserRole.superAdmin => '/super_admin'
          });
      expect(find.byType(AuthLoadingScreen), findsNothing);
      expect(releases, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'slow login uses fallback only after grace and does not preserve native again',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = MultiAuthFixture();
    var releases = 0;
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith((ref) => auth),
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      tenantAccessProvider.overrideWithValue(null),
      nativeSplashProvider
          .overrideWithValue(NativeSplashController.testing(() => releases++)),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const GeneratorPortalApp()));
    await tester.pumpAndSettle();
    expect(releases, 1);
    auth.replace(
        AuthState(user: PhoneUser('u'), loading: true, startupResolved: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 799));
    expect(find.byType(AuthLoadingScreen), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.byType(AuthLoadingScreen), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(releases, 1);
    auth.replace(const AuthState(startupResolved: true, loading: false));
    await tester.pumpAndSettle();
    expect(find.byType(AuthLoadingScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'cold start holds native splash through profile and generator resolution',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = MultiAuthFixture(const AuthState());
    final tenantState = StateProvider<AsyncValue<GeneratorAccount>>(
        (ref) => const AsyncLoading());
    var releases = 0;
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith((ref) => auth),
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      tenantAccessProvider.overrideWith((ref) => ref.watch(tenantState)),
      nativeSplashProvider
          .overrideWithValue(NativeSplashController.testing(() => releases++)),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const GeneratorPortalApp()));
    await tester.pump(const Duration(seconds: 1));
    expect(releases, 0);
    expect(find.text('تسجيل الدخول'), findsNothing);
    auth.replace(AuthState(
        user: PhoneUser('u'),
        loading: false,
        startupResolved: true,
        profile: UserProfile(
            uid: '',
            name: 'مشترك',
            role: UserRole.consumer,
            generatorId: 'g',
            createdAt: DateTime(2026))));
    await tester.pump();
    expect(releases, 0);
    container.read(tenantState.notifier).state = const AsyncData(
        GeneratorAccount(
            id: 'g',
            name: 'مولد',
            sector: 'الرمال',
            status: GeneratorApproval.approved));
    await tester.pumpAndSettle();
    expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/consumer');
    expect(releases, 1);
    expect(find.byType(AuthLoadingScreen), findsNothing);
    expect(find.text('تسجيل الدخول'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  test('inactive or suspended generators keep approved owners out of home', () {
    final profile = UserProfile(
        uid: 'owner',
        name: 'مالك',
        role: UserRole.admin,
        generatorId: 'g',
        createdAt: DateTime(2026));
    expect(
        authRedirect(
            path: '/admin',
            startupResolved: true,
            loading: false,
            loggedIn: true,
            profile: profile,
            tenantAvailable: false),
        '/account-status');
    expect(
        authRedirect(
            path: '/account-status',
            startupResolved: true,
            loading: false,
            loggedIn: true,
            profile: profile,
            tenantAvailable: true),
        '/admin');
  });

  test('cached profile lookup is UID bound and never reuses another account',
      () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('old').set({'role': 'super_admin'});
    expect(
        (await readCachedProfile(db, 'old'))?.data()?['role'], 'super_admin');
    expect((await readCachedProfile(db, 'new'))?.exists, false);
    expect(await readCachedProfile(db, ''), isNull);
  });

  test(
      'subscription transaction updates live picker, preserves review status and private fields',
      () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('sa').set({'role': 'super_admin'});
    await db.collection('users').doc('owner').set({
      'role': 'generator_owner',
      'generatorId': 'g',
      'status': 'approved',
      'name': 'خاص'
    });
    await db.collection('generators').doc('g').set({
      'name': 'مولد النور',
      'sector': 'الرمال',
      'ownerUid': 'owner',
      'status': 'approved',
      'subscriptionStatus': 'active'
    });
    final store = TenantStore(db, () => 'sa');
    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(db),
      authProvider.overrideWith((ref) => MultiAuthFixture(AuthState(
          user: PhoneUser('sa'), startupResolved: true, loading: false)))
    ]);
    addTearDown(container.dispose);
    final events = <List<GeneratorAccount>>[];
    final sub = container.listen(generatorDirectoryProvider, (_, value) {
      if (value.hasValue) events.add(value.requireValue);
    }, fireImmediately: true);
    addTearDown(sub.close);
    await store.setGeneratorSubscription('g', true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(events.last.single.id, 'g');
    await store.setGeneratorSubscription('g', false);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(events.last, isEmpty);
    expect((await db.collection('generators').doc('g').get()).data()?['status'],
        'approved');
    expect((await db.collection('users').doc('owner').get()).data()?['status'],
        'approved');
    expect(
        (await db.collection('generatorDirectory').doc('g').get())
            .data()!
            .keys
            .toSet(),
        {'name', 'sector', 'status', 'subscriptionStatus'});
    await db.collection('generators').doc('g').update({'status': 'suspended'});
    await store.setGeneratorSubscription('g', true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
        events.last, isEmpty); // Active does not approve a suspended request.
    await store.reviewGenerator('g', GeneratorApproval.approved);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(events.last.single.id, 'g');
  });

  test('owner cannot change subscription', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('owner').set(
        {'role': 'generator_owner', 'generatorId': 'g', 'status': 'approved'});
    expect(TenantStore(db, () => 'owner').setGeneratorSubscription('g', true),
        throwsStateError);
  });
}
