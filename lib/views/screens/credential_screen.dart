import '../../services/contact_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/enrollment_provider.dart';
import '../../models/user_model.dart';
import '../../services/credential_service.dart';
import '../../theme/portal_tokens.dart';
import '../widgets/portal_components.dart';

enum CredentialMode { login, create, recover, verify, manage }

class CredentialScreen extends ConsumerStatefulWidget {
  final CredentialMode mode;
  const CredentialScreen({super.key, required this.mode});
  @override
  ConsumerState<CredentialScreen> createState() => _CredentialScreenState();
}

class _CredentialScreenState extends ConsumerState<CredentialScreen> {
  final email = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController(),
      current = TextEditingController();
  final phone = TextEditingController(), id = TextEditingController();
  bool busy = false, reauthenticated = false;
  String? error, notice;
  CredentialService get service => ref.read(credentialServiceProvider);
  @override
  void initState() {
    super.initState();
    final profile = ref.read(authProvider).profile;
    phone.text = profile?.phone ?? '';
    id.text = profile?.idNumber ?? '';
    password.addListener(refresh);
    confirm.addListener(refresh);
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [email, password, confirm, current, phone, id]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    final flow = ref.read(credentialFlowProvider.notifier);
    flow.state = true;
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = credentialError(e));
    } finally {
      flow.state = false;
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() => run(() async {
        switch (widget.mode) {
          case CredentialMode.login:
            final problem = await ref
                .read(authProvider.notifier)
                .login(email.text.trim(), password.text);
            if (problem != null) throw CredentialFailure(problem);
          case CredentialMode.create:
            await service.registerEmail(
                email.text.trim(), password.text, confirm.text);
            await ref.read(authProvider.notifier).reloadProfile();
          case CredentialMode.recover:
            await service.sendReset(email.text.trim());
            if (mounted) {
              setState(() => notice =
                  'إذا كان البريد مسجلاً فستصلك رسالة لإعادة تعيين كلمة المرور. راجع أيضاً البريد غير المرغوب.');
            }
          case CredentialMode.verify:
            await service.refresh();
            await ref.read(authProvider.notifier).reloadProfile();
            if (!service.verified) {
              throw const CredentialFailure(
                  'لم يتم التحقق بعد. افتح رابط الرسالة ثم أعد المحاولة.');
            }
          case CredentialMode.manage:
            if (password.text.isNotEmpty && !reauthenticated) {
              throw const CredentialFailure('تحقق بكلمة المرور الحالية أولاً');
            }
            if (id.text.isNotEmpty && !validNationalId(id.text.trim())) {
              throw const CredentialFailure(
                  'الهوية اختيارية؛ أدخل 9 أو 10 أرقام');
            }
            if (password.text.isNotEmpty) {
              final issue = passwordError(password.text, confirm.text,
                  id.text.trim(), phone.text.trim());
              if (issue != null) throw CredentialFailure(issue);
              await service.changePassword(
                  password.text, confirm.text, id.text.trim(),
                  phone: phone.text.trim());
            }
            await service.finishAccount(
                id: normalizeDigits(id.text).trim(), phone: normalizeMobile(phone.text));
            await ref.read(authProvider.notifier).reloadProfile();
            if (mounted) setState(() => notice = 'تم حفظ بيانات الحساب');
        }
      });
  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final title = switch (mode) {
      CredentialMode.login => 'تسجيل الدخول',
      CredentialMode.create => 'إنشاء حساب',
      CredentialMode.recover => 'استعادة كلمة المرور',
      CredentialMode.verify => 'تحقق من بريدك',
      CredentialMode.manage => 'إعدادات الحساب'
    };
    final passwordFields = {
      CredentialMode.login,
      CredentialMode.create,
      CredentialMode.manage
    }.contains(mode);
    return PortalPage(
        title: title,
        subtitle: 'بوابة المولدات',
        reserveNavigation: false,
        children: [
          if (mode == CredentialMode.login &&
              ref.watch(loginNoticeProvider) != null)
            PortalPanel(child: Text(ref.watch(loginNoticeProvider)!)),
          if (mode == CredentialMode.create) ...[
            const Text(
                'أنشئ حسابك بالبريد الإلكتروني، ثم أكمل طلب الانضمام إلى مولدك.'),
            Row(children: [
              for (final role in [UserRole.consumer, UserRole.admin])
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.all(PortalTokens.xs),
                        child: OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () => ref
                                    .read(enrollmentRoleProvider.notifier)
                                    .state = role,
                            icon: Icon(ref.watch(enrollmentRoleProvider) == role
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off),
                            label: Text(role == UserRole.admin
                                ? 'صاحب مولد'
                                : 'مشترك'))))
            ]),
          ],
          if (mode == CredentialMode.verify) ...[
            const PortalSection('افتح رسالة التحقق في بريدك'),
            Text(service.email, textDirection: TextDirection.ltr),
            const Text(
                'افتح رابط رسالة التحقق ثم عد إلى التطبيق واضغط «تحققت من البريد».'),
            TextButton(
                onPressed: busy
                    ? null
                    : () => run(() async {
                          await service.sendVerification();
                          if (mounted) {
                            setState(() => notice =
                                'أُرسلت رسالة التحقق. راجع البريد غير المرغوب أيضاً.');
                          }
                        }),
                child: const Text('إعادة إرسال رسالة التحقق')),
          ] else if (mode != CredentialMode.manage) ...[
            TextField(
                key: const ValueKey('email'),
                controller: email,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني الحقيقي')),
            const SizedBox(height: PortalTokens.lg),
          ],
          if (mode == CredentialMode.manage) ...[
            Text(service.email, textDirection: TextDirection.ltr),
            TextField(
                controller: current,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'كلمة المرور الحالية')),
            TextButton(
                onPressed: busy
                    ? null
                    : () => run(() async {
                          await service.reauthenticatePassword(current.text);
                          if (mounted) setState(() => reauthenticated = true);
                        }),
                child: const Text('التحقق من الحساب')),
            TextField(
                key: const ValueKey('contact-phone'),
                controller: phone,
                keyboardType: TextInputType.phone,
                maxLength: 32,
                decoration: const InputDecoration(
                    labelText: 'هاتف التواصل (غير متحقق منه)')),
            TextField(
                key: const ValueKey('contact-id'),
                controller: id,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'رقم الهوية (اختياري وخاص)')),
          ],
          if (passwordFields) ...[
            TextField(
                key: const ValueKey('password'),
                controller: password,
                obscureText: true,
                enabled: !busy,
                autofillHints: mode == CredentialMode.login
                    ? const [AutofillHints.password]
                    : null,
                decoration: InputDecoration(
                    labelText: mode == CredentialMode.manage
                        ? 'كلمة مرور جديدة (اختياري)'
                        : 'كلمة المرور')),
            if (mode != CredentialMode.login) ...[
              const Text(passwordRules),
              if (password.text.isNotEmpty)
                Text(passwordError(password.text, confirm.text, id.text.trim(),
                        phone.text.trim()) ??
                    'كلمة المرور تستوفي الشروط'),
              TextField(
                  key: const ValueKey('password-confirm'),
                  controller: confirm,
                  obscureText: true,
                  enabled: !busy,
                  decoration:
                      const InputDecoration(labelText: 'تأكيد كلمة المرور')),
            ],
          ],
          if (error != null) PortalErrorState(error!),
          if (notice != null) PortalPanel(child: Text(notice!)),
          const SizedBox(height: PortalTokens.lg),
          PortalActionButton(
              label: switch (mode) {
                CredentialMode.login => 'تسجيل الدخول',
                CredentialMode.create => 'إنشاء الحساب وإرسال التحقق',
                CredentialMode.recover => 'إرسال رابط الاستعادة',
                CredentialMode.verify => 'تحققت من البريد',
                CredentialMode.manage => 'حفظ التغييرات'
              },
              busy: busy,
              onPressed: submit),
          if (mode == CredentialMode.login) ...[
            TextButton(
                onPressed: () => context.go('/forgot-password'),
                child: const Text('نسيت كلمة المرور؟')),
            TextButton(
                onPressed: () => context.go('/register'),
                child: const Text('ليس لديك حساب؟ أنشئ حساباً')),
          ] else if (mode == CredentialMode.verify ||
              mode == CredentialMode.manage)
            TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        await ref.read(authProvider.notifier).signOut();
                        if (context.mounted) context.go('/login');
                      },
                child: const Text('تسجيل الخروج'))
          else
            TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('العودة إلى الدخول')),
          if (mode == CredentialMode.manage)
            TextButton(
                onPressed: () => context.go(
                    ref.read(authProvider).profile?.role == UserRole.admin
                        ? '/admin'
                        : ref.read(authProvider).profile?.role == UserRole.meterReader ? '/reader' : '/consumer'),
                child: const Text('رجوع')),
        ]);
  }
}
