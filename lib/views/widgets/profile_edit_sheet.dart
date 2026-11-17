import '../../services/contact_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../theme/portal_tokens.dart';
import 'portal_keyboard.dart';

class ProfileEditSheet extends ConsumerStatefulWidget {
  final String title;
  const ProfileEditSheet({super.key, this.title = 'تعديل البيانات'});
  @override
  ConsumerState<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<ProfileEditSheet> {
  late final name =
      TextEditingController(text: ref.read(authProvider).profile?.name ?? '');
  late final address = TextEditingController(
      text: ref.read(authProvider).profile?.address ?? '');
  late final phone =
      TextEditingController(text: ref.read(authProvider).profile?.phone ?? '');
  late final id = TextEditingController(
      text: ref.read(authProvider).profile?.idNumber ?? '');
  bool saving = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    address.dispose();
    phone.dispose();
    id.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    final issue = contactError(phone.text, id.text);
    if (issue != null || name.text.trim().isEmpty) {
      setState(() => error = issue ?? 'أدخل الاسم');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref.read(authProvider.notifier).updateProfile(
          name: name.text.trim(),
          address: address.text.trim(),
          phone: normalizeMobile(phone.text),
          idNumber: normalizeDigits(id.text).trim());
      if (mounted) completePortalSave(context, message: 'تم حفظ البيانات ✓');
    } catch (_) {
      if (mounted) {
        setState(
            () => error = 'تعذر حفظ البيانات؛ تحقق من الاتصال وحاول مجدداً');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
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
                  onPressed: saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close))
            ]),
            for (final entry in [
              (name, 'الاسم الكامل', Icons.person_outline),
              (address, 'العنوان', Icons.location_on_outlined),
              (phone, 'رقم الجوال', Icons.phone_outlined),
              (id, 'رقم الهوية (اختياري وخاص)', Icons.badge_outlined)
            ])
              Padding(
                  padding: const EdgeInsets.only(top: PortalTokens.md),
                  child: TextField(
                      controller: entry.$1,
                      keyboardType: entry.$1 == phone
                          ? TextInputType.phone
                          : entry.$1 == id
                              ? TextInputType.number
                              : TextInputType.text,
                      decoration: InputDecoration(
                          hintText: entry.$2, prefixIcon: Icon(entry.$3)))),
            OutlinedButton.icon(
                onPressed: saving
                    ? null
                    : () {
                        final router = GoRouter.of(context);
                        completePortalSave(context);
                        router.go('/account-security');
                      },
                icon: const Icon(Icons.manage_accounts_outlined),
                label: const Text('تغيير كلمة المرور')),
            if (error != null) Text(error!),
            ElevatedButton(
                onPressed: saving ? null : save,
                child: Text(saving ? 'جارٍ الحفظ…' : 'حفظ التغييرات'))
          ]));
}

class ContactCompletionPrompt extends ConsumerWidget {
  const ContactCompletionPrompt({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider).profile?.phone.isNotEmpty != false) {
      return const SizedBox.shrink();
    }
    return Padding(
        padding: const EdgeInsets.only(bottom: PortalTokens.lg),
        child: Card(
            child: Padding(
                padding: PortalTokens.panelPadding,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                          'أكمل هاتف التواصل ليسهل الوصول إليك؛ يمكنك متابعة استخدام التطبيق.'),
                      TextButton(
                          onPressed: () => showPortalFormSheet(
                              context: context,
                              builder: (_) => const ProfileEditSheet()),
                          child: const Text('إكمال بيانات التواصل'))
                    ]))));
  }
}
