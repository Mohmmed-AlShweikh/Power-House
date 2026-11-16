import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/portal_tokens.dart';
import '../../views/widgets/portal_components.dart';
import '../../views/widgets/portal_keyboard.dart';

class FeatureLoading extends StatelessWidget {
  const FeatureLoading({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'جارٍ التحميل',
      child: Column(children: [
        for (var i = 0; i < 3; i++)
          Padding(
              padding: const EdgeInsets.only(bottom: PortalTokens.lg),
              child: Container(
                  height: PortalTokens.target,
                  decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius:
                          BorderRadius.circular(PortalTokens.radius))))
      ]));
}

class FeatureData<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T) builder;
  final VoidCallback retry;
  const FeatureData(
      {super.key,
      required this.value,
      required this.builder,
      required this.retry});
  @override
  Widget build(BuildContext context) => value.when(
      data: builder,
      loading: () => const FeatureLoading(),
      error: (_, __) => Column(children: [
            const PortalErrorState(
                'تعذر تحميل البيانات بعد المحاولات التلقائية'),
            TextButton(onPressed: retry, child: const Text('إعادة المحاولة'))
          ]));
}

Future<void> featureAction(
    BuildContext context, Future<void> Function() action) async {
  try {
    await action();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حفظ العملية')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is StateError
              ? e.message.toString()
              : e is FormatException
                  ? e.message
                  : 'تعذر الحفظ؛ تحقق من الاتصال والصلاحية ثم حاول مجدداً')));
    }
  }
}

Future<bool> featureConfirm(BuildContext context, String title) async =>
    await showPortalFormDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text(title),
                content: const Text('هل تريد المتابعة؟'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('تأكيد'))
                ])) ??
    false;
Future<Map<String, String>?> featureForm(
        BuildContext context, String title, Map<String, String> initial,
        {Set<String> numeric = const {}, Set<String> optional = const {}}) =>
    showPortalFormSheet<Map<String, String>>(
        context: context,
        builder: (_) => _Fields(title, initial, numeric, optional));

class _Fields extends StatefulWidget {
  final String title;
  final Map<String, String> initial;
  final Set<String> numeric, optional;
  const _Fields(this.title, this.initial, this.numeric, this.optional);
  @override
  State<_Fields> createState() => _FieldsState();
}

class _FieldsState extends State<_Fields> {
  late final fields = {
    for (final e in widget.initial.entries)
      e.key: TextEditingController(text: e.value)
  };
  String? error;
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
      padding: PortalTokens.pagePadding,
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                  child: Text(widget.title,
                      style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                  tooltip: 'إغلاق',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close))
            ]),
            for (final e in fields.entries)
              Padding(
                  padding: const EdgeInsets.only(top: PortalTokens.lg),
                  child: TextField(
                      controller: e.value,
                      keyboardType: widget.numeric.contains(e.key)
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.text,
                      decoration: InputDecoration(labelText: e.key))),
            if (error != null) Text(error!),
            const SizedBox(height: PortalTokens.xl),
            PortalActionButton(
                label: 'حفظ',
                onPressed: () {
                  if (fields.entries.any((e) =>
                      !widget.optional.contains(e.key) &&
                      e.value.text.trim().isEmpty)) {
                    setState(() => error = 'أكمل الحقول المطلوبة');
                    return;
                  }
                  Navigator.pop(context, {
                    for (final e in fields.entries) e.key: e.value.text.trim()
                  });
                })
          ]));
}
