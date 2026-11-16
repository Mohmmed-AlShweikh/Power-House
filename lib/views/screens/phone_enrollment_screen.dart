import 'package:flutter/material.dart';
import '../../services/credential_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/enrollment_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../theme/portal_tokens.dart';
import '../widgets/portal_components.dart';

class EnrollmentFormScreen extends ConsumerStatefulWidget {
  const EnrollmentFormScreen({super.key});
  @override
  ConsumerState<EnrollmentFormScreen> createState() =>
      _EnrollmentFormScreenState();
}

class _EnrollmentFormScreenState extends ConsumerState<EnrollmentFormScreen> {
  final name = TextEditingController(), sector = TextEditingController();
  final contactPhone = TextEditingController();
  final nationalId = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  String search = '', selectedSector = '', selectedId = '';
  String? error;
  bool busy = false;
  @override
  void dispose() {
    name.dispose();
    sector.dispose();
    contactPhone.dispose();
    nationalId.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> submit(bool owner) async {
    if((nationalId.text.trim().isNotEmpty&&!validNationalId(nationalId.text.trim()))||contactPhone.text.length>32){setState(()=>error='الهوية اختيارية ومن 9 أو 10 أرقام؛ تحقق من بيانات التواصل');return;}

    if (name.text.trim().isEmpty ||
        (owner && sector.text.trim().isEmpty) ||
        (!owner && selectedId.isEmpty)) {
      setState(() => error = 'أكمل البيانات واختر المولد');
      return;
    }
    if (!owner) {
      final directory = ref.read(generatorDirectoryProvider);
      if (directory.isLoading ||
          directory.hasError ||
          !(directory.valueOrNull
                  ?.any((g) => g.id == selectedId && g.available) ??
              false)) {
        setState(() => error = 'المولد المختار غير متاح. اختر مولداً آخر.');
        return;
      }
    }
    setState(() {
      busy = true;
      error = null;
    });
    final flow = ref.read(credentialFlowProvider.notifier);
    flow.state = true;
    try {
      final auth = ref.read(authProvider.notifier);
      if (owner) {
        await auth.enrollOwner(name.text.trim(), sector.text.trim(),
            phone: contactPhone.text.trim(), idNumber: nationalId.text.trim());
      } else {
        await auth.enrollConsumer(name.text.trim(), selectedId,
            phone: contactPhone.text.trim(), idNumber: nationalId.text.trim());
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = credentialError(e));
      }
    } finally {
      flow.state = false;
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
              label: 'البريد الإلكتروني',
              value: ref.watch(authProvider).user?.email ?? '—'),
          const SizedBox(height: PortalTokens.lg),
          PortalInput(
              label: owner ? 'اسم المولد' : 'الاسم الكامل', controller: name),
          const SizedBox(height: PortalTokens.lg),
          PortalInput(
              label: 'هاتف التواصل (اختياري وغير متحقق منه)',
              controller: contactPhone,
              keyboardType: TextInputType.phone),
          const SizedBox(height: PortalTokens.lg),
          PortalInput(
              label: 'رقم الهوية (اختياري وخاص)',
              controller: nationalId,
              keyboardType: TextInputType.number),
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
                  final effectiveSector =
                      sectors.contains(selectedSector) ? selectedSector : '';
                  final matches = items
                      .where((g) =>
                          g.available &&
                          (effectiveSector.isEmpty ||
                              g.sector == effectiveSector) &&
                          g.name.toLowerCase().contains(search.toLowerCase()))
                      .toList();
                  return <Widget>[
                    DropdownButtonFormField<String>(
                        key: ValueKey('$effectiveSector:${sectors.join('|')}'),
                        initialValue: effectiveSector,
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
