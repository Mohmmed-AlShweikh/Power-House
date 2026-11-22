import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generator_portal/views/widgets/portal_numeric_field.dart';
import 'package:generator_portal/views/widgets/portal_password_field.dart';

void main() {
  testWidgets('numeric middle editing deletion and paste keep cursor in RTL',
      (t) async {
    final c = TextEditingController();
    addTearDown(c.dispose);
    await t.pumpWidget(MaterialApp(
        home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
                body: PortalNumericField(
                    controller: c, keyboardType: TextInputType.number)))));
    await t.tap(find.byType(TextField));
    for (final value in const [
      TextEditingValue(
          text: '١٢٣', selection: TextSelection.collapsed(offset: 3)),
      TextEditingValue(
          text: '١٩٢٣', selection: TextSelection.collapsed(offset: 2)),
      TextEditingValue(
          text: '١٢٣', selection: TextSelection.collapsed(offset: 1)),
      TextEditingValue(
          text: '۱۲۳۴', selection: TextSelection.collapsed(offset: 4))
    ]) {
      t.testTextInput.updateEditingValue(value);
      await t.pump();
      expect(c.selection, value.selection);
      expect(c.text, matches(RegExp(r'^\d+$')));
    }
    final field = t.widget<TextField>(find.byType(TextField));
    expect(field.textDirection, TextDirection.ltr);
    expect(field.textAlign, TextAlign.right);
  });
  test(
      'digit replacement preserves selection for middle edit paste delete and composing',
      () {
    const f = PortalDigitFormatter();
    for (final value in [
      const TextEditingValue(
          text: '١٢٣', selection: TextSelection.collapsed(offset: 3)),
      const TextEditingValue(
          text: '١٩٢٣', selection: TextSelection.collapsed(offset: 2)),
      const TextEditingValue(
          text: '١٣', selection: TextSelection.collapsed(offset: 1)),
      const TextEditingValue(
          text: '۱۲۳', selection: TextSelection(baseOffset: 0, extentOffset: 3))
    ]) {
      final out = f.formatEditUpdate(TextEditingValue.empty, value);
      expect(out.selection, value.selection);
      expect(out.text, isNot(contains('١')));
    }
  });
  testWidgets('eye keeps password cursor and is hidden by default', (t) async {
    final c = TextEditingController(text: 'Strong123');
    addTearDown(c.dispose);
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PortalPasswordField(controller: c, label: 'كلمة المرور'))));
    c.selection = const TextSelection.collapsed(offset: 3);
    expect(t.widget<TextField>(find.byType(TextField)).obscureText, true);
    await t.tap(find.byTooltip('إظهار كلمة المرور'));
    await t.pump();
    expect(t.widget<TextField>(find.byType(TextField)).obscureText, false);
    expect(c.selection.baseOffset, 3);
  });
}
