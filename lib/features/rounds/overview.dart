import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../theme/portal_tokens.dart';
import '../../views/widgets/portal_components.dart';
import '../../views/widgets/portal_keyboard.dart';
import '../../views/widgets/portal_number.dart';
import '../billing_settings/models.dart';
import '../billing_shared/widgets.dart';
import '../metering/providers.dart';
import 'providers.dart';
import 'selectors.dart';

class RoundsOverview extends ConsumerWidget {
  const RoundsOverview({super.key});
  Future<void> add(BuildContext context, WidgetRef ref) async {
    final choice = await showPortalFormSheet<String>(
        context: context,
        builder: (c) => Padding(
            padding: PortalTokens.pagePadding,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('إضافة مشترك للفوترة',
                  style: Theme.of(c).textTheme.titleLarge),
              ListTile(
                  leading: const Icon(Icons.person_add_outlined),
                  title: const Text('إضافة مشترك يدوي'),
                  subtitle: const Text(
                      'سجّل اسمه وعدادَه لمن لا يملك حساباً في التطبيق.'),
                  onTap: () => Navigator.pop(c, 'manual')),
              ListTile(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: const Text('إضافة حساب معتمد'),
                  subtitle:
                      const Text('اختر مشتركاً وافقت عليه ليظهر له كشف حسابه.'),
                  onTap: () => Navigator.pop(c, 'account'))
            ])));
    if (choice == null || !context.mounted) return;
    if (choice == 'account') {
      final user = await chooseConsumer(context);
      if (user == null || !context.mounted) return;
      final v = await featureForm(context, 'إضافة الحساب للفوترة',
          {'رقم الاشتراك': '', 'قراءة البداية': '0'},
          numeric: {'قراءة البداية'});
      if (v != null && context.mounted) {
        await featureAction(context, () async {
          await ref.read(roundsRepositoryProvider).addSubscriber(
              name: user.name,
              phone: user.phone,
              address: user.address,
              number: v['رقم الاشتراك']!,
              startingMilli: parseFixed(v['قراءة البداية']!, 3),
              userId: user.uid);
        });
      }
    } else {
      final v = await featureForm(context, 'إضافة مشترك يدوي', {
        'الاسم': '',
        'هاتف التواصل': '',
        'الحي / العنوان': '',
        'رقم الاشتراك': '',
        'قراءة البداية': '0'
      }, numeric: {
        'قراءة البداية'
      }, optional: {
        'هاتف التواصل',
        'الحي / العنوان'
      });
      if (v != null && context.mounted) {
        await featureAction(context, () async {
          await ref.read(roundsRepositoryProvider).addSubscriber(
              name: v['الاسم']!,
              phone: v['هاتف التواصل']!,
              address: v['الحي / العنوان']!,
              number: v['رقم الاشتراك']!,
              startingMilli: parseFixed(v['قراءة البداية']!, 3));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: AppBar(title: const Text('جولات القراءة والفوترة'), actions: [
        IconButton(
            tooltip: 'كشف الحساب',
            onPressed: () => context.push('/cycle-statement'),
            icon: const Icon(Icons.receipt_long_outlined))
      ]),
      body: ListView(padding: PortalTokens.pagePadding, children: [
        Text('قراءات منظمة وفاتورة واحدة لكل مشترك',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: PortalTokens.lg),
        PortalActionButton(
            label: 'فتح جولة',
            onPressed: () => featureAction(context, () async {
                  final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now());
                  if (date != null) {
                    await ref.read(roundsRepositoryProvider).openRound(
                        DateTime.utc(date.year, date.month, date.day));
                  }
                })),
        const SizedBox(height: PortalTokens.sm),
        OutlinedButton.icon(
            onPressed: () => add(context, ref),
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('إضافة')),
        const PortalSection('الجولات'),
        FeatureData(
            value: ref.watch(billingRoundsProvider),
            retry: () => ref.invalidate(billingRoundsProvider),
            builder: (s) {
              final rows = [...s.docs]..sort((a, b) =>
                  (b.data()['date'] as int).compareTo(a.data()['date'] as int));
              return rows.isEmpty
                  ? const PortalEmptyState('أضف المشتركين ثم افتح أول جولة')
                  : Column(children: [
                      for (final d in rows)
                        Padding(
                            padding:
                                const EdgeInsets.only(bottom: PortalTokens.lg),
                            child: RoundOverviewCard(id: d.id, data: d.data()))
                    ]);
            }),
        const PortalSection('المشتركون المسجلون للفوترة'),
        FeatureData(
            value: ref.watch(billingSubscribersProvider),
            retry: () => ref.invalidate(billingSubscribersProvider),
            builder: (s) => s.docs.isEmpty
                ? const PortalEmptyState('لا يوجد مشتركون للفوترة؛ اختر إضافة')
                : Column(children: [
                    for (final d in s.docs)
                      Padding(
                          padding:
                              const EdgeInsets.only(bottom: PortalTokens.lg),
                          child:
                              SubscriberOverviewCard(id: d.id, data: d.data()))
                  ]))
      ]));
}

class RoundOverviewCard extends ConsumerWidget {
  final String id;
  final Map<String, dynamic> data;
  const RoundOverviewCard({super.key, required this.id, required this.data});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = data['status'];
    final closed = state == 'closed';
    final published =
        closed && ref.watch(roundPublishedProvider(id)).valueOrNull == true;
    final total = (data['subscriberIds'] as List).length;
    final progress =
        closed ? total : ref.watch(roundReadingsProvider(id)).valueOrNull?.size;
    final label = published
        ? 'منشورة'
        : {
              'preparing': 'قيد التحضير',
              'open': 'مفتوحة',
              'closing': 'قيد إصدار الفواتير',
              'closed': 'مغلقة'
            }[state] ??
            'قيد التحضير';
    final action = published
        ? 'عرض كشف الحساب'
        : closed
            ? 'إرسال الفواتير'
            : state == 'preparing'
                ? 'متابعة التحضير'
                : state == 'closing'
                    ? 'استئناف إصدار الفواتير'
                    : 'متابعة القراءات';
    return PortalPanel(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
            child: Text('جولة القراءة',
                style: Theme.of(context).textTheme.titleLarge)),
        PortalStatusChip(
            label: label,
            tone: published
                ? PortalTone.success
                : closed
                    ? PortalTone.stopped
                    : PortalTone.working,
            icon: published
                ? Icons.done_all
                : closed
                    ? Icons.lock_outline
                    : Icons.electric_meter_outlined)
      ]),
      const SizedBox(height: PortalTokens.md),
      PortalLabelValue(
          label: 'تاريخ الجولة',
          value: DateTime.fromMillisecondsSinceEpoch(data['date'], isUtc: true)
              .toIso8601String()
              .substring(0, 10)),
      PortalLabelValue(label: 'المشتركون', value: '$total'),
      PortalLabelValue(
          label: 'القراءات المسجلة', value: '${progress ?? '—'} / $total'),
      if (progress != null)
        LinearProgressIndicator(
            value: total == 0 ? 0 : (progress / total).clamp(0, 1),
            semanticsLabel: 'تقدم تسجيل القراءات'),
      const SizedBox(height: PortalTokens.lg),
      FilledButton.tonal(
          onPressed: () => context.push(published
              ? '/cycle-statement'
              : closed
                  ? '/distribution'
                  : '/round/$id'),
          child: Text(action)),
      if (closed)
        TextButton(
            onPressed: () => context.push('/round/$id'),
            child: const Text('تفاصيل الجولة'))
    ]));
  }
}

class SubscriberOverviewCard extends ConsumerWidget {
  final String id;
  final Map<String, dynamic> data;
  const SubscriberOverviewCard(
      {super.key, required this.id, required this.data});
  Future<void> act(BuildContext context, WidgetRef ref, String action) async {
    if (action == 'link') {
      final u = await chooseConsumer(context);
      if (u != null && context.mounted) {
        await featureAction(context,
            () => ref.read(roundsRepositoryProvider).linkAccount(id, u.uid));
      }
      return;
    }
    if (action == 'repair') {
      await featureAction(
          context, () => ref.read(roundsRepositoryProvider).repairLinks(id));
      return;
    }
    if (action == 'reader') {
      final uid = await chooseReader(context);
      if (uid != null && context.mounted) {
        await featureAction(context,
            () => ref.read(roundsRepositoryProvider).assignReader(id, uid));
      }
      return;
    }
    if (action == 'edit') {
      final v = await featureForm(context, 'تعديل بيانات المشترك', {
        'الاسم': data['name'],
        'هاتف التواصل': data['phone'],
        'الحي / العنوان': data['address'],
        'رقم الاشتراك': data['number']
      }, optional: {
        'هاتف التواصل',
        'الحي / العنوان'
      });
      if (v != null && context.mounted) {
        await featureAction(
            context,
            () => ref.read(roundsRepositoryProvider).editSubscriber(id,
                name: v['الاسم']!,
                phone: v['هاتف التواصل']!,
                address: v['الحي / العنوان']!,
                number: v['رقم الاشتراك']!));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linked = (data['userId'] as String).isNotEmpty;
    final pending = linked && data['linkPending'] == true;
    final own = ref.watch(authProvider).user?.uid == data['readerUid'];
    final staff = ref
        .watch(meterStaffProvider)
        .valueOrNull
        ?.docs
        .where((d) => d.id == data['readerUid'])
        .toList();
    final reader = own
        ? 'صاحب المولد'
        : staff?.isNotEmpty == true
            ? staff!.single.data()['name'] as String
            : 'قارئ مسند';
    return PortalPanel(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
            child: Text(data['name'],
                style: Theme.of(context).textTheme.titleLarge)),
        PopupMenuButton<String>(
            tooltip: 'إجراءات المشترك',
            onSelected: (v) => act(context, ref, v),
            itemBuilder: (_) => [
                  if (!linked)
                    const PopupMenuItem(
                        value: 'link',
                        child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.link),
                            title: Text('ربط بحساب'),
                            subtitle: Text(
                                'اربطه بمشترك مسجل ليرى فواتيره في التطبيق.'))),
                  if (pending)
                    const PopupMenuItem(
                        value: 'repair',
                        child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.sync),
                            title: Text('إكمال الربط'),
                            subtitle: Text(
                                'أكمل نقل الفواتير والدفعات بعد انقطاع سابق.'))),
                  const PopupMenuItem(
                      value: 'reader',
                      child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.badge_outlined),
                          title: Text('إسناد قارئ'),
                          subtitle: Text('اختر من يسجل قراءة هذا العداد.'))),
                  const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('تعديل'),
                          subtitle: Text(
                              'الاسم والتواصل والمنطقة ورقم الاشتراك فقط.')))
                ])
      ]),
      Text('${data['number']} • ${data['address']}',
          style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: PortalTokens.md),
      Text('القراءة السابقة', style: Theme.of(context).textTheme.bodySmall),
      PortalNumber(formatFixed(data['previousMilli'], 3),
          style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: PortalTokens.md),
      Wrap(spacing: PortalTokens.sm, runSpacing: PortalTokens.sm, children: [
        PortalStatusChip(
            label: reader,
            tone: PortalTone.stopped,
            icon: Icons.badge_outlined),
        PortalStatusChip(
            label: pending
                ? 'الربط غير مكتمل'
                : linked
                    ? 'حساب مرتبط'
                    : 'مشترك يدوي',
            tone: pending
                ? PortalTone.warning
                : linked
                    ? PortalTone.success
                    : PortalTone.stopped,
            icon: pending
                ? Icons.sync_problem
                : linked
                    ? Icons.link
                    : Icons.person_outline)
      ]),
      if (pending)
        Padding(
            padding: const EdgeInsets.only(top: PortalTokens.sm),
            child: Text(
                'حُفظ الحساب ولم يكتمل ربط فواتيره؛ اختر إكمال الربط من القائمة.',
                style: Theme.of(context).textTheme.bodySmall))
    ]));
  }
}
