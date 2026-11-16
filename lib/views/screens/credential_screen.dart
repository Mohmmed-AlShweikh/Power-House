import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../services/credential_service.dart';
import '../../theme/portal_tokens.dart';
import '../widgets/portal_components.dart';

enum CredentialMode { complete, recover, create, manage }

class CredentialScreen extends ConsumerStatefulWidget {
  final CredentialMode mode;
  const CredentialScreen({super.key, required this.mode});
  @override
  ConsumerState<CredentialScreen> createState() => _CredentialScreenState();
}

class _CredentialScreenState extends ConsumerState<CredentialScreen> {
  final id = TextEditingController(),
      phone = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController(),
      current = TextEditingController(),
      code = TextEditingController();
  String? verificationId, error;
  bool busy = false, authenticated = false, matched = false, created = false;
  PhoneOperation operation = PhoneOperation.signIn;
  CredentialService? pendingPhone;
  CredentialService get service => ref.read(credentialServiceProvider);
  bool get recovery => widget.mode == CredentialMode.recover;
  bool get management => widget.mode == CredentialMode.manage;
  @override
  void initState() {
    super.initState();
    final profile = ref.read(authProvider).profile;
    if (!recovery && widget.mode != CredentialMode.create) {
      final recorded = profile?.idNumber ?? '';
      final emailId = service.email.split('@').first;
      id.text = service.hasPassword && validNationalId(emailId)
          ? emailId
          : (validNationalId(recorded) ? recorded : '');
      phone.text = service.hasPhone ? service.phone : profile?.phone ?? '';
    }
    password.addListener(refresh);
    confirm.addListener(refresh);
    id.addListener(refresh);
    phone.addListener(refresh);
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    pendingPhone?.cancelPhone();
    for (final c in [id, phone, password, confirm, current, code]) {
      c.dispose();
    }
    super.dispose();
  }

  void hold() => ref.read(credentialFlowProvider.notifier).state = true;
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = credentialError(e);
          if (management) authenticated = false;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> send(PhoneOperation op) => run(() async {
        hold();
        final targetPhone = op == PhoneOperation.reauthenticate
            ? service.phone
            : phone.text.trim();
        if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(targetPhone)) {
          throw const CredentialFailure('أدخل الهاتف مع رمز الدولة');
        }
        if (recovery && !validNationalId(id.text.trim())) {
          throw const CredentialFailure('أدخل رقم هوية من 9 أو 10 أرقام');
        }
        if (widget.mode == CredentialMode.create && !created) {
          await service.createId(id.text.trim(), password.text, confirm.text);
          created = true;
        }
        operation = op;
        pendingPhone = service;
        await service.sendPhone(
            op == PhoneOperation.reauthenticate
                ? service.phone
                : phone.text.trim(),
            op, verified: () {
          if (mounted) {
            setState(() => busy = false);
            run(afterPhoneVerified);
          }
        }, sent: (value) {
          if (mounted) {
            setState(() {
              verificationId = value;
              busy = false;
            });
          }
        }, failed: (message) {
          if (mounted) {
            setState(() {
              error = message;
              busy = false;
            });
          }
        });
      });
  Future<void> verify() => run(() async {
        if (!RegExp(r'^\d{6}$').hasMatch(code.text.trim())) {
          throw const CredentialFailure('أدخل رمز التحقق المكوّن من 6 أرقام');
        }
        await service.verifyPhone(verificationId!, code.text.trim(), operation);
        await afterPhoneVerified();
      });
  Future<void> afterPhoneVerified() async {
    verificationId = null;
    code.clear();
    if (recovery) {
      matched = await service.matchRecoveryId(id.text.trim());
      if (!matched) {
        await ref.read(authProvider.notifier).signOut();
        throw const CredentialFailure(genericAuthError);
      }
    } else if (operation == PhoneOperation.reauthenticate) {
      authenticated = true;
    } else if (widget.mode == CredentialMode.create ||
        (widget.mode == CredentialMode.complete &&
            ref.read(authProvider).profile == null)) {
      await ref.read(authProvider.notifier).reloadProfile();
      ref.read(credentialFlowProvider.notifier).state = false;
      if (mounted) context.go('/onboarding');
    }
  }

  Future<void> submit() => run(() async {
        hold();
        final nationalId = id.text.trim();
        if (!validNationalId(nationalId)) {
          throw const CredentialFailure('أدخل رقم هوية من 9 أو 10 أرقام');
        }
        if (recovery) {
          if (!matched) throw const CredentialFailure(genericAuthError);
          await service.resetPassword(nationalId, password.text, confirm.text);
          await ref.read(authProvider.notifier).signOut();
          ref.read(loginNoticeProvider.notifier).state =
              'تم تغيير كلمة المرور. سجّل الدخول بكلمة المرور الجديدة.';
          ref.read(credentialFlowProvider.notifier).state = false;
          if (mounted) context.go('/login');
          return;
        }
        if (!service.hasPhone || phone.text.trim() != service.phone) {
          throw const CredentialFailure('تحقق من رقم الهاتف أولاً');
        }
        if (management) {
          if (!authenticated) {
            throw const CredentialFailure('أعد التحقق من هويتك أولاً');
          }
          if (password.text.isNotEmpty) {
            final issue = passwordError(
                password.text, confirm.text, nationalId, phone.text.trim());
            if (issue != null) throw CredentialFailure(issue);
          }
          await service.changeIdentity(nationalId);
          if (password.text.isNotEmpty) {
            await service.changePassword(
                password.text, confirm.text, nationalId);
          }
        } else {
          if (!service.hasPassword) {
            await service.linkId(nationalId, password.text, confirm.text);
          }
          await service.changeIdentity(nationalId);
        }
        await ref.read(authProvider.notifier).reloadProfile();
        ref.read(credentialFlowProvider.notifier).state = false;
        if (mounted) {
          context.go(ref.read(authProvider).profile?.role == UserRole.admin
              ? '/admin'
              : '/consumer');
        }
      });
  Future<void> cancel() async {
    if (!management) await ref.read(authProvider.notifier).signOut();
    ref.read(credentialFlowProvider.notifier).state = false;
    if (mounted) {
      context.go(management
          ? (ref.read(authProvider).profile?.role == UserRole.admin
              ? '/admin'
              : '/consumer')
          : '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsPassword = recovery
        ? matched
        : widget.mode == CredentialMode.create ||
            management ||
            !service.hasPassword;
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !busy) cancel();
        },
        child: PortalPage(
            title: recovery
                ? 'استعادة كلمة المرور'
                : management
                    ? 'إعدادات الدخول'
                    : widget.mode == CredentialMode.create
                        ? 'التسجيل برقم الهوية'
                        : 'إكمال طرق الدخول',
            subtitle: recovery
                ? 'التحقق من الهاتف المسجّل'
                : 'حساب واحد بالهاتف والهوية',
            reserveNavigation: false,
            children: [
              if (widget.mode == CredentialMode.complete)
                const Text(
                    'أكمل ربط الهاتف والهوية مرة واحدة للدخول بالطريقتين إلى حسابك نفسه.'),
              TextField(
                  key: const ValueKey('credential-id'),
                  controller: id,
                  enabled: !busy && !matched && !created,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'رقم الهوية')),
              const SizedBox(height: PortalTokens.lg),
              if (!matched) ...[
                TextField(
                    key: const ValueKey('credential-phone'),
                    controller: phone,
                    enabled: !busy && verificationId == null,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'رقم الهاتف مع رمز الدولة')),
                const SizedBox(height: PortalTokens.lg),
              ],
              if (management && !authenticated) ...[
                TextField(
                    controller: current,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'كلمة المرور الحالية')),
                PortalActionButton(
                    label: 'تحقق بكلمة المرور الحالية',
                    busy: busy,
                    onPressed: () => run(() async {
                          hold();
                          await service.reauthenticatePassword(current.text);
                          authenticated = true;
                        })),
                if (service.hasPhone)
                  TextButton(
                      onPressed: busy
                          ? null
                          : () => send(PhoneOperation.reauthenticate),
                      child:
                          const Text('التحقق برمز الهاتف المسجّل بدلاً منها')),
              ],
              if (recovery && matched) const PortalSection('كلمة مرور جديدة'),
              if (needsPassword) ...[
                TextField(
                    key: const ValueKey('credential-password'),
                    controller: password,
                    obscureText: true,
                    decoration: InputDecoration(
                        labelText: management
                            ? 'كلمة مرور جديدة (اختياري)'
                            : 'كلمة المرور الجديدة')),
                const SizedBox(height: PortalTokens.sm),
                const Text(passwordRules),
                if (password.text.isNotEmpty)
                  Text(passwordError(password.text, confirm.text,
                          id.text.trim(), phone.text.trim()) ??
                      'كلمة المرور تستوفي الشروط'),
                const SizedBox(height: PortalTokens.lg),
                TextField(
                    key: const ValueKey('credential-confirm'),
                    controller: confirm,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'تأكيد كلمة المرور')),
                const SizedBox(height: PortalTokens.lg),
              ],
              if (verificationId != null) ...[
                TextField(
                    key: const ValueKey('credential-otp'),
                    controller: code,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(labelText: 'رمز التحقق')),
                PortalActionButton(
                    label: 'تحقق من الرمز', busy: busy, onPressed: verify),
                TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                              verificationId = null;
                              code.clear();
                            }),
                    child: const Text('تعديل الرقم أو طلب رمز جديد')),
              ] else if ((recovery && !matched) ||
                  widget.mode == CredentialMode.create ||
                  (!recovery &&
                      (!service.hasPhone ||
                          phone.text.trim() != service.phone)))
                PortalActionButton(
                    label: 'إرسال رمز التحقق',
                    busy: busy,
                    onPressed: management && !authenticated
                        ? null
                        : () => send(recovery
                            ? PhoneOperation.signIn
                            : management
                                ? PhoneOperation.change
                                : PhoneOperation.link)),
              if (error != null) PortalErrorState(error!),
              if ((recovery && matched) ||
                  management ||
                  widget.mode == CredentialMode.complete)
                PortalActionButton(
                    label: recovery ? 'حفظ كلمة المرور' : 'حفظ ومتابعة',
                    busy: busy,
                    onPressed: submit),
              TextButton(
                  onPressed: busy ? null : cancel,
                  child: Text(management ? 'رجوع' : 'العودة إلى الدخول')),
            ]));
  }
}
