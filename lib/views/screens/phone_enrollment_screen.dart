import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/enrollment_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../services/phone_auth_service.dart';
import '../../theme/portal_tokens.dart';
import '../widgets/portal_components.dart';

class PhoneEnrollmentScreen extends ConsumerStatefulWidget {
  const PhoneEnrollmentScreen({super.key});
  @override
  ConsumerState<PhoneEnrollmentScreen> createState() =>
      _PhoneEnrollmentScreenState();
}

class _PhoneEnrollmentScreenState extends ConsumerState<PhoneEnrollmentScreen> {
  final phone = TextEditingController(text: '+970');
  final code = TextEditingController();
  String? verificationId, error;
  bool busy = false;
  @override
  void dispose() {
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone.text.trim())) {
      setState(() => error = 'أدخل رقم الهاتف مع رمز الدولة، مثل +970');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(phoneGatewayProvider).send(phone.text.trim(),
          codeSent: (id) {
        if (mounted) {
          setState(() {
            verificationId = id;
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
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'تعذّر إرسال الرمز. حاول مجدداً.';
          busy = false;
        });
      }
    }
  }

  Future<void> verify() async {
    if (!RegExp(r'^\d{6}$').hasMatch(code.text.trim())) {
      setState(() => error = 'أدخل رمز التحقق المكوّن من 6 أرقام');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(phoneGatewayProvider)
          .verify(verificationId!, code.text.trim());
    } catch (_) {
      if (mounted) {
        setState(() => error = 'رمز التحقق غير صحيح أو انتهت صلاحيته');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(enrollmentRoleProvider);
    return PortalPage(
        title: 'بوابة المولدات',
        subtitle: 'التحقق من الهاتف',
        reserveNavigation: false,
        children: [
          const PortalSection('نوع الحساب'),
          Row(children: [
            for (final item in [
              (UserRole.consumer, 'مشترك'),
              (UserRole.admin, 'صاحب مولد')
            ])
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.all(PortalTokens.xs),
                      child: OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () => ref
                                  .read(enrollmentRoleProvider.notifier)
                                  .state = item.$1,
                          icon: Icon(role == item.$1
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off),
                          label: Text(item.$2))))
          ]),
          const SizedBox(height: PortalTokens.xl),
          PortalPanel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                TextField(
                    controller: phone,
                    enabled: verificationId == null && !busy,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'رقم الهاتف مع رمز الدولة')),
                const SizedBox(height: PortalTokens.lg),
                if (verificationId != null) ...[
                  TextField(
                      controller: code,
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration:
                          const InputDecoration(labelText: 'رمز التحقق')),
                  const SizedBox(height: PortalTokens.lg)
                ],
                if (error != null) ...[
                  PortalErrorState(error!),
                  const SizedBox(height: PortalTokens.lg)
                ],
                PortalActionButton(
                    label: verificationId == null
                        ? 'إرسال رمز التحقق'
                        : 'تحقق ومتابعة',
                    busy: busy,
                    onPressed: verificationId == null ? send : verify),
                if (verificationId != null)
                  TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                                verificationId = null;
                                code.clear();
                                error = null;
                              }),
                      child: const Text('تعديل الرقم أو إعادة إرسال الرمز')),
              ])),
          TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('الدخول برقم الهوية')),
        ]);
  }
}

class EnrollmentFormScreen extends ConsumerStatefulWidget {
  const EnrollmentFormScreen({super.key});
  @override
  ConsumerState<EnrollmentFormScreen> createState() =>
      _EnrollmentFormScreenState();
}

class _EnrollmentFormScreenState extends ConsumerState<EnrollmentFormScreen> {
  final name = TextEditingController(), sector = TextEditingController();
  String search = '', selectedSector = '', selectedId = '';
  String? error;
  bool busy = false;
  @override
  void dispose() {
    name.dispose();
    sector.dispose();
    super.dispose();
  }

  Future<void> submit(bool owner) async {
    if (name.text.trim().isEmpty ||
        (owner && sector.text.trim().isEmpty) ||
        (!owner && selectedId.isEmpty)) {
      setState(() => error = 'أكمل البيانات واختر المولد');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final auth = ref.read(authProvider.notifier);
      if (owner) {
        await auth.enrollOwner(name.text.trim(), sector.text.trim());
      } else {
        await auth.enrollConsumer(name.text.trim(), selectedId);
      }
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'تعذّر تقديم الطلب. تحقق من الاتصال وتوفر المولد ثم حاول مجدداً.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(enrollmentRoleProvider) == UserRole.admin;
    return PortalPage(
        title: owner ? 'تسجيل المولد' : 'اختيار المولد',
        subtitle: 'إكمال طلب التسجيل',
        reserveNavigation: false,
        children: [
          PortalLabelValue(
              label: 'الهاتف المتحقق منه',
              value: ref.watch(authProvider).user?.phoneNumber ?? '—'),
          const SizedBox(height: PortalTokens.lg),
          PortalInput(
              label: owner ? 'اسم المولد' : 'الاسم الكامل', controller: name),
          const SizedBox(height: PortalTokens.lg),
          if (owner)
            PortalInput(label: 'القطاع / الحي', controller: sector)
          else ...[
            const PortalSection('المولدات المتاحة'),
            ...ref.watch(generatorDirectoryProvider).when(
                loading: () => [const PortalLoadingState()],
                error: (_, __) => [
                      const PortalErrorState('تعذّر تحميل المولدات'),
                      TextButton(
                          onPressed: () =>
                              ref.invalidate(generatorDirectoryProvider),
                          child: const Text('إعادة المحاولة'))
                    ],
                data: (items) {
                  final sectors = items.map((g) => g.sector).toSet().toList()
                    ..sort();
                  final matches = items
                      .where((g) =>
                          g.available &&
                          (selectedSector.isEmpty ||
                              g.sector == selectedSector) &&
                          g.name.toLowerCase().contains(search.toLowerCase()))
                      .toList();
                  return <Widget>[
                    DropdownButtonFormField<String>(
                        initialValue: selectedSector,
                        decoration:
                            const InputDecoration(labelText: 'القطاع / الحي'),
                        items: [
                          const DropdownMenuItem(
                              value: '', child: Text('جميع القطاعات')),
                          for (final s in sectors)
                            DropdownMenuItem(value: s, child: Text(s))
                        ],
                        onChanged: busy
                            ? null
                            : (s) => setState(() {
                                  selectedSector = s ?? '';
                                  selectedId = '';
                                })),
                    const SizedBox(height: PortalTokens.lg),
                    PortalInput(
                        label: 'البحث باسم المولد',
                        onChanged: (s) => setState(() {
                              search = s;
                              selectedId = '';
                            })),
                    const SizedBox(height: PortalTokens.lg),
                    if (matches.isEmpty)
                      const PortalEmptyState(
                          'لا توجد مولدات متاحة تطابق البحث'),
                    for (final g in matches)
                      PortalPanel(
                          child: ListTile(
                              leading: Icon(selectedId == g.id
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off),
                              title: Text(g.name),
                              subtitle: Text(g.sector),
                              selected: selectedId == g.id,
                              onTap: busy
                                  ? null
                                  : () => setState(() => selectedId = g.id))),
                  ];
                }),
          ],
          const SizedBox(height: PortalTokens.xl),
          if (error != null) PortalErrorState(error!),
          PortalActionButton(
              label: 'تقديم الطلب', busy: busy, onPressed: () => submit(owner)),
          TextButton(
              onPressed: busy
                  ? null
                  : () => ref.read(enrollmentRoleProvider.notifier).state =
                      owner ? UserRole.consumer : UserRole.admin,
              child: Text(owner ? 'التسجيل كمشترك' : 'التسجيل كصاحب مولد')),
          TextButton(
              onPressed:
                  busy ? null : () => ref.read(authProvider.notifier).signOut(),
              child: const Text('تسجيل الخروج')),
        ]);
  }
}
