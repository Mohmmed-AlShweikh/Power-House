import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/portal_tokens.dart';
import '../../views/widgets/portal_components.dart';
import '../../views/widgets/portal_keyboard.dart';
import '../../views/widgets/portal_number.dart';
import 'models.dart';
import 'providers.dart';

class BillingSettingsScreen extends ConsumerWidget {
  const BillingSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: AppBar(title: const Text('إعدادات الفوترة')),
      body: ref.watch(billingSettingsProvider).when(
          loading: () => Semantics(
              label: 'جارٍ تحميل إعدادات الفوترة',
              child: ListView(padding: PortalTokens.pagePadding, children: [
                for (var i = 0; i < 5; i++)
                  Padding(
                      padding: const EdgeInsets.only(bottom: PortalTokens.lg),
                      child: Container(
                          height: PortalTokens.target,
                          decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius:
                                  BorderRadius.circular(PortalTokens.radius))))
              ])),
          error: (_, __) => Column(children: [
                const PortalErrorState('تعذر تحميل الإعدادات'),
                TextButton(
                    onPressed: () => ref.invalidate(billingSettingsProvider),
                    child: const Text('إعادة المحاولة'))
              ]),
          data: (s) => _SettingsForm(initial: s)));
}

class _SettingsForm extends ConsumerStatefulWidget {
  final BillingSettings initial;
  const _SettingsForm({required this.initial});
  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late final List<TextEditingController> fields;
  bool busy = false;
  String? message;
  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    fields = [
      formatFixed(s.priceAgorot, 2),
      s.unitName,
      formatFixed(s.minimumUnitsMilli, 3),
      s.cycleDays.toString(),
      s.roundingThresholdAgorot.toString()
    ].map((text) => TextEditingController(text: text)).toList();
  }

  @override
  void dispose() {
    for (final c in fields) {
      c.dispose();
    }
    super.dispose();
  }

  BillingSettings values() => BillingSettings(
      priceAgorot: parseFixed(fields[0].text, 2),
      unitName: fields[1].text.trim(),
      minimumUnitsMilli: parseFixed(fields[2].text, 3),
      cycleDays: int.parse(fields[3].text),
      roundingThresholdAgorot: int.parse(fields[4].text));
  Widget preview() {
    try {
      final result = calculateBill(
          previousMilli: 20000, currentMilli: 30000, settings: values());
      return PortalPanel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('مثال حسابي: قراءة سابقة 20، حالية 30'),
        PortalNumber('₪${formatFixed(result.amountAgorot, 2)}',
            style: Theme.of(context).textTheme.titleLarge),
        if (result.minimumApplied) const Text('تم تطبيق الحد الأدنى'),
      ]));
    } catch (_) {
      return const Text('أكمل القيم لعرض مثال الحساب');
    }
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final s = values();
      await ref.read(billingSettingsRepositoryProvider).save(s);
      if (mounted) {
        setState(() => message = 'تم الحفظ؛ الفواتير السابقة لا تتغير');
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => message = 'تعذر الحفظ؛ تحقق من القيم والاتصال والصلاحية');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PortalFocusReveal(
          child: ListView(padding: PortalTokens.pagePadding, children: [
        const Text(
            'تُطبّق على الفواتير الجديدة فقط. العملة: ₪. الحد الأدنى بوحدات الاستهلاك، ثم التقريب إلى شيكل كامل.'),
        for (var i = 0; i < fields.length; i++)
          Padding(
              padding: const EdgeInsets.only(top: PortalTokens.lg),
              child: TextField(
                  controller: fields[i],
                  onChanged: (_) => setState(() {}),
                  keyboardType: i == 1
                      ? TextInputType.text
                      : const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: [
                    'سعر الوحدة (₪)',
                    'اسم الوحدة',
                    'الحد الأدنى (وحدات)',
                    'طول الدورة بالأيام',
                    'عتبة التقريب بالأغورات (1–99)'
                  ][i]))),
        const SizedBox(height: PortalTokens.lg),
        preview(),
        if (message != null)
          Padding(
              padding: PortalTokens.panelPadding,
              child: Text(message!, semanticsLabel: message)),
        const SizedBox(height: PortalTokens.xl),
        PortalActionButton(label: 'حفظ الإعدادات', busy: busy, onPressed: save)
      ]));
}
