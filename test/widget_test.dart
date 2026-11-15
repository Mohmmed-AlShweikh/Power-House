import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:generator_portal/main.dart';
import 'package:generator_portal/providers/auth_provider.dart';
import 'support/multi_auth_fixture.dart';

void main() {
  testWidgets(
      'signed-out startup displays login without Firebase initialization',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(overrides: [
      authProvider.overrideWith((ref) => MultiAuthFixture()),
    ], child: const GeneratorPortalApp()));
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الدخول'), findsWidgets);
    expect(find.widgetWithText(TextField, 'xxxxxxxxxx'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
