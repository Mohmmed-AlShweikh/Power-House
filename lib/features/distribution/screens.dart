import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/portal_tokens.dart';
import '../../views/widgets/portal_components.dart';
import '../billing_shared/widgets.dart';
import '../rounds/providers.dart';
import 'providers.dart';
import 'models.dart';

class DistributionScreen extends ConsumerStatefulWidget {
  const DistributionScreen({super.key});
  @override
  ConsumerState<DistributionScreen> createState() => _DistributionScreenState();
}

class _DistributionScreenState extends ConsumerState<DistributionScreen> {
  bool busy = false;
  String? result;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('إرسال الفواتير')),
      body: ListView(padding: PortalTokens.pagePadding, children: [
        const Text(
            'النشر ينشئ تنبيهات داخل التطبيق للحسابات المرتبطة. لا يضمن وصول تنبيه فوري والتطبيق مغلق. الإرسال الآلي لواتساب أو SMS يحتاج بنية خارجية، وليس ضمن التطبيق.'),
        if (result != null) PortalPanel(child: Text(result!)),
        FeatureData(
            value: ref.watch(billingRoundsProvider),
            retry: () => ref.invalidate(billingRoundsProvider),
            builder: (s) {
              final rows = s.docs.where((d) => d.data()['status'] == 'closed');
              return rows.isEmpty
                  ? const PortalEmptyState('أغلق جولة قراءة أولاً')
                  : Column(children: [
                      for (final d in rows)
                        PortalPanel(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                              Text(
                                  'جولة ${DateTime.fromMillisecondsSinceEpoch(d.data()['date'], isUtc: true).toIso8601String().substring(0, 10)}',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              PortalActionButton(
                                  label: 'إرسال الفواتير لجميع المشتركين',
                                  busy: busy,
                                  onPressed: () async {
                                    if (!await featureConfirm(context,
                                            'نشر جميع فواتير الجولة؟') ||
                                        !context.mounted) {
                                      return;
                                    }
                                    setState(() => busy = true);
                                    await featureAction(context, () async {
                                      final r = await ref
                                          .read(distributionRepositoryProvider)
                                          .publish(d.id);
                                      if (mounted) {
                                        setState(() => result =
                                            'نُشرت: ${r.sent} • تنبيهات داخلية: ${r.notified} • متجاوزة: ${r.skipped} • تعذرت: ${r.failed}. يمكن إعادة المحاولة دون تكرار.');
                                      }
                                    });
                                    if (mounted) setState(() => busy = false);
                                  }),
                              TextButton(
                                  onPressed: () =>
                                      context.push('/bill-sharing/${d.id}'),
                                  child: const Text(
                                      'قائمة واتساب / المشاركة اليدوية'))
                            ]))
                    ]);
            })
      ]));
}

class BillSharingScreen extends ConsumerWidget {
  final String rid;
  const BillSharingScreen(this.rid, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marks = ref
            .watch(billSharesProvider(rid))
            .valueOrNull
            ?.docs
            .map((d) => d.id)
            .toSet() ??
        {};
    return Scaffold(
        appBar: AppBar(title: const Text('قائمة واتساب')),
        body: ListView(padding: PortalTokens.pagePadding, children: [
          const Text(
              'افتح المشاركة واختر واتساب والمستلم يدوياً. فتح قائمة المشاركة لا يعني التسليم؛ علّم الفاتورة بعد الإرسال الفعلي.'),
          FeatureData(
              value: ref.watch(shareBillsProvider(rid)),
              retry: () => ref.invalidate(shareBillsProvider(rid)),
              builder: (s) => s.docs.isEmpty
                  ? const PortalEmptyState('لا توجد فواتير للجولة')
                  : Column(children: [
                      for (final d in s.docs)
                        PortalPanel(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                              Text(d.data()['name'],
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              SelectableText(billShareText(d.data())),
                              Text(marks.contains(d.id)
                                  ? 'تم تعليمها كمرسلة يدوياً'
                                  : 'لم تُعلّم بعد'),
                              Wrap(children: [
                                TextButton.icon(
                                    onPressed: () => featureAction(
                                        context,
                                        () => ref
                                            .read(
                                                distributionRepositoryProvider)
                                            .share(d.id)),
                                    icon: const Icon(Icons.share_outlined),
                                    label: const Text('فتح المشاركة')),
                                TextButton(
                                    onPressed: () => featureAction(
                                        context,
                                        () => ref
                                            .read(
                                                distributionRepositoryProvider)
                                            .markShared(d.id)),
                                    child: const Text('تم الإرسال يدوياً'))
                              ])
                            ]))
                    ]))
        ]));
  }
}
