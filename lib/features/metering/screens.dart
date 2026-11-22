import 'package:generator_portal/views/widgets/portal_numeric_field.dart';
import '../../views/widgets/profile_edit_sheet.dart';
import '../../views/widgets/portal_keyboard.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../theme/portal_tokens.dart';
import '../../views/widgets/portal_components.dart';
import '../../views/widgets/portal_number.dart';
import '../billing_settings/models.dart';
import '../billing_shared/widgets.dart';
import 'models.dart';
import 'providers.dart';

class MeterStaffScreen extends ConsumerWidget {
  const MeterStaffScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: AppBar(title: const Text('عمال قراءة العدادات')),
      body: ListView(padding: PortalTokens.pagePadding, children: [
        PortalActionButton(
            label: 'إنشاء رمز دعوة',
            onPressed: () async {
              final input = await featureForm(context, 'دعوة عامل',
                  {'الصلاحية بالأيام (0 بلا انتهاء)': '7'},
                  numeric: {'الصلاحية بالأيام (0 بلا انتهاء)'});
              if (input == null || !context.mounted) return;
              await featureAction(context, () async {
                final days = int.parse(input.values.single);
                if (days < 0 || days > 366) {
                  throw const FormatException('الصلاحية بين 0 و366 يوماً');
                }
                await ref.read(meteringRepositoryProvider).invite(
                    expiresAt: days == 0
                        ? 0
                        : DateTime.now()
                            .add(Duration(days: days))
                            .millisecondsSinceEpoch);
              });
            }),
        const PortalSection('الدعوات (تُستخدم مرة واحدة)'),
        FeatureData(
            value: ref.watch(meterInvitesProvider),
            retry: () => ref.invalidate(meterInvitesProvider),
            builder: (s) => Column(children: [
                  for (final d in s.docs)
                    PortalPanel(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          SelectableText(d.id,
                              textDirection: TextDirection.ltr),
                          Text(d.data()['revoked'] == true
                              ? 'ملغاة'
                              : d.data()['usedBy'] != ''
                                  ? 'مستخدمة'
                                  : 'متاحة'),
                          if (d.data()['revoked'] == false)
                            TextButton(
                                onPressed: () => featureAction(
                                    context,
                                    () => ref
                                        .read(meteringRepositoryProvider)
                                        .revokeInvite(d.id)),
                                child: const Text('إلغاء الدعوة'))
                        ]))
                ])),
        const PortalSection('العمال'),
        FeatureData(
            value: ref.watch(meterStaffProvider),
            retry: () => ref.invalidate(meterStaffProvider),
            builder: (s) => s.docs.isEmpty
                ? const PortalEmptyState(
                    'لا يوجد عمال؛ أنشئ دعوة وشارك رمزها مع العامل')
                : Column(children: [
                    for (final d in s.docs)
                      ListTile(
                          leading: const Icon(Icons.badge_outlined),
                          title: Text(d.data()['name']),
                          subtitle: Text(d.data()['active'] ? 'نشط' : 'ملغى'),
                          trailing: d.data()['active']
                              ? TextButton(
                                  onPressed: () async {
                                    if (await featureConfirm(
                                            context, 'إلغاء صلاحية العامل؟') &&
                                        context.mounted) {
                                      await featureAction(
                                          context,
                                          () => ref
                                              .read(meteringRepositoryProvider)
                                              .revokeReader(d.id));
                                    }
                                  },
                                  child: const Text('إلغاء الصلاحية'))
                              : null)
                  ]))
      ]));
}

class ReaderJoinScreen extends ConsumerWidget {
  const ReaderJoinScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: AppBar(title: const Text('الانضمام كقارئ عدادات')),
      body: Padding(
          padding: PortalTokens.pagePadding,
          child: Column(children: [
            const Text(
                'أنشئ حساب البريد وتحقق منه أولاً، ثم أدخل دعوة صاحب المولد. لا تتيح صلاحية العامل الاطلاع على الأموال.'),
            PortalActionButton(
                label: 'إدخال رمز الدعوة',
                onPressed: () async {
                  final v = await featureForm(context, 'بيانات العامل',
                      {'الاسم': '', 'رمز الدعوة': ''});
                  if (v == null || !context.mounted) return;
                  await featureAction(context, () async {
                    final auth = ref.read(authProvider);
                    await ref.read(meteringRepositoryProvider).join(
                        uid: auth.user!.uid,
                        email: auth.user!.email!,
                        code: v['رمز الدعوة']!,
                        name: v['الاسم']!);
                    await ref.read(authProvider.notifier).reloadProfile();
                  });
                })
          ])));
}

class MeterReaderScreen extends ConsumerWidget {
  const MeterReaderScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: AppBar(title: const Text('قراءة العدادات'), actions: [
 IconButton(tooltip:'بياناتي',onPressed:()=>showPortalFormSheet(context:context,builder:(_)=>const ProfileEditSheet()),icon:const Icon(Icons.person_outline)),
        IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: () => ref.read(authProvider.notifier).signOut(),
            icon: const Icon(Icons.logout))
      ]),
      body: ListView(padding: PortalTokens.pagePadding, children: [
        const ContactCompletionPrompt(),
        FeatureData(
            value: ref.watch(meterAssignmentsProvider),
            retry: () => ref.invalidate(meterAssignmentsProvider),
            builder: (rows) => rows.isEmpty
                ? PortalEmptyState(ref.watch(readerOpenRoundProvider).valueOrNull?.data()?['status']=='preparing'?'الجولة قيد التحضير؛ ستظهر عداداتك عندما يفتحها صاحب المولد':ref.watch(readerOpenRoundProvider).valueOrNull?.data()?['status']=='open'?'جولة مفتوحة لكن لا توجد عدادات مسندة لك؛ تواصل مع صاحب المولد':'لا توجد جولة مفتوحة')
                : Column(children: [
                    for (final row in rows)
                      MeterEntry(key: ValueKey(row.id), row: row)
                  ]))
      ]));
}

class MeterEntry extends ConsumerStatefulWidget {
  final MeterAssignment row;
  const MeterEntry({super.key, required this.row});
  @override
  ConsumerState<MeterEntry> createState() => _MeterEntryState();
}

class _MeterEntryState extends ConsumerState<MeterEntry> {
  final input = TextEditingController();
  final saveFocus = FocusNode(skipTraversal: true);
  String? message;
  @override
  void dispose() {
    input.dispose();
    saveFocus.dispose();
    super.dispose();
  }

  Future<void> save() async {
    try {
      final current = parseFixed(input.text, 3);
      var confirmed = false;
      if (widget.row.abnormal(current)) {
        confirmed = await featureConfirm(
            context, 'قفزة أكبر من ثلاثة أضعاف المتوسط؛ تأكيد القراءة؟');
        if (!confirmed) return;
      }
      // Firestore persists this deterministic write offline. Do not block next entry.
      final pending = ref
          .read(meteringRepositoryProvider)
          .save(widget.row, current, confirmed: confirmed);
      setState(() => message = 'بانتظار المزامنة');
      if (mounted) FocusScope.of(context).nextFocus();
      unawaited(pending.then((_) {
        if (mounted) setState(() => message = 'تم الحفظ');
      }).catchError((Object e) {
        if (mounted) {
          setState(() => message = e is StateError
              ? e.message.toString()
              : 'تعذر المزامنة؛ راجع القراءة والصلاحية ثم أعد الحفظ');
        }
      }));
    } catch (_) {
      if (mounted) {
        setState(() => message = 'أدخل قراءة صحيحة لا تقل عن السابقة');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final saved = ref.watch(meterReadingProvider(row.id));
    return Padding(
        padding: const EdgeInsets.only(bottom: PortalTokens.lg),
        child: PortalPanel(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Text(row.name, style: Theme.of(context).textTheme.titleLarge),
              Text('${row.address} • ${row.number}'),
              PortalLabelValue(
                  label: 'القراءة السابقة',
                  value: formatFixed(row.previousMilli, 3)),
              PortalNumericField(
                  controller: input,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => save(),
                  decoration:
                      const InputDecoration(labelText: 'القراءة الحالية')),
              if (saved.valueOrNull != null)
                PortalNumber(
                    'المحفوظة: ${formatFixed(saved.valueOrNull!.currentMilli, 3)}'),
              Text(saved.valueOrNull?.pending == true
                  ? 'بانتظار المزامنة'
                  : message ??
                      (saved.valueOrNull != null
                          ? 'تم الحفظ'
                          : 'لم تُسجّل بعد')),
              TextButton.icon(
                  focusNode: saveFocus,
                  onPressed: save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('حفظ والانتقال للتالي'))
            ])));
  }
}
