import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../models/user_model.dart';
import '../../../models/complaint_model.dart';
import '../../../services/firebase_service.dart';
import '../../../services/notification_service.dart';
import '../../../config/colors.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).profile;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final initials = (profile?.name.isNotEmpty == true)
        ? profile!.name[0].toUpperCase()
        : '؟';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.primaryDark,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                tooltip: isDark ? 'وضع النهار' : 'وضع الليل',
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode,
                    color: Colors.white),
                onPressed: () => ref.read(themeProvider.notifier).toggle(),
              ),
              IconButton(
                tooltip: 'تسجيل الخروج',
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () async {
                  await ref.read(authProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [AppColors.primaryDark, AppColors.primary],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.5), width: 2),
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                          profile?.name.isNotEmpty == true
                              ? profile!.name
                              : 'مستخدم',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          profile?.role == UserRole.admin
                              ? 'صاحب مولد'
                              : 'مستهلك',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _InfoCard(),
                const SizedBox(height: 16),

                // ── الحساب ──────────────────────────────────────────────────
                _SettingsGroup(title: 'الحساب', items: [
                  _SettingsItem(Icons.edit_outlined, 'تعديل البيانات',
                      AppColors.warning, () {
                    _showEditSheet(context, ref);
                  }),
                ]),
                const SizedBox(height: 16),

                // ── المظهر ───────────────────────────────────────────────────
                _ThemeToggleCard(isDark: isDark, ref: ref),
                const SizedBox(height: 16),

                // ── الدعم ────────────────────────────────────────────────────
                _SettingsGroup(title: 'الدعم', items: [
                  _SettingsItem(
                      Icons.report_problem_outlined,
                      'إرسال شكوى',
                      AppColors.error,
                      () => _showComplaintSheet(context, ref)),
                  _SettingsItem(
                      Icons.history_outlined,
                      'شكاواي',
                      AppColors.primary,
                      () => _showMyComplaintsSheet(context, ref)),
                ]),
                const SizedBox(height: 24),

                // ── تسجيل الخروج ─────────────────────────────────────────────
                _LogoutButton(ref: ref, context: context),
                const SizedBox(height: 24),

                Center(
                  child: Text('بوابة المولدات v1.0.0',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.lightMuted.withOpacity(0.6))),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    final profile = ref.read(authProvider).profile;
    final nameCtrl = TextEditingController(text: profile?.name ?? '');
    final addressCtrl = TextEditingController(text: profile?.address ?? '');
    final phoneCtrl = TextEditingController(text: profile?.phone ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('تعديل البيانات',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SheetField(
                    controller: nameCtrl,
                    hint: 'الاسم الكامل',
                    icon: Icons.person_outline),
                const SizedBox(height: 12),
                _SheetField(
                    controller: addressCtrl,
                    hint: 'العنوان',
                    icon: Icons.location_on_outlined),
                const SizedBox(height: 12),
                _SheetField(
                    controller: phoneCtrl,
                    hint: 'رقم الجوال',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 20),
                StatefulBuilder(builder: (ctx, setS) {
                  bool saving = false;
                  return ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            setS(() => saving = true);
                            await ref
                                .read(authProvider.notifier)
                                .updateProfile(
                                  name: nameCtrl.text.trim(),
                                  address: addressCtrl.text.trim(),
                                  phone: phoneCtrl.text.trim(),
                                );
                            setS(() => saving = false);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('تم حفظ البيانات ✓',
                                        textAlign: TextAlign.right)),
                              );
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : const Text('حفظ التغييرات'),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSecuritySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _SecuritySheet(),
    );
  }

  void _showHelpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _HelpSheet(),
    );
  }

  void _showComplaintSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: const _ComplaintSheet(),
      ),
    );
  }

  void _showMyComplaintsSheet(BuildContext context, WidgetRef ref) {
    final uid = ref.read(authProvider).profile?.uid ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _MyComplaintsSheet(uid: uid),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  const _SheetField(
      {required this.controller,
      required this.hint,
      required this.icon,
      this.keyboardType});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.lightMuted),
          prefixIcon: Icon(icon, color: AppColors.lightMuted, size: 20),
          filled: true,
          fillColor: Theme.of(context).scaffoldBackgroundColor,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.lightBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.lightBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      );
}

class _InfoCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).profile;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          _InfoRow(Icons.phone, 'رقم الهاتف', profile?.phone ?? '—'),
          const Divider(height: 20, color: AppColors.lightBorder),
          _InfoRow(Icons.location_on_outlined, 'العنوان',
              profile?.address?.isNotEmpty == true ? profile!.address : '—'),
          const Divider(height: 20, color: AppColors.lightBorder),
          _InfoRow(
              Icons.badge_outlined,
              'نوع الحساب',
              profile?.role == UserRole.admin ? 'صاحب مولد' : 'مستهلك'),
          const Divider(height: 20, color: AppColors.lightBorder),
          _InfoRow(
              Icons.calendar_today,
              'تاريخ الانضمام',
              profile != null
                  ? '${profile.createdAt.day}/${profile.createdAt.month}/${profile.createdAt.year}'
                  : '—'),
        ],
      ),
    ).animate().fadeIn();
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.lightMuted)),
                const SizedBox(height: 1),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      );
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;
  const _SettingsGroup({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, right: 4),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.lightMuted)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final isLast = e.key == items.length - 1;
              return Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: e.value.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(e.value.icon,
                          size: 18, color: e.value.color),
                    ),
                    title: Text(e.value.label,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    trailing: const Icon(Icons.chevron_left,
                        color: AppColors.lightMuted, size: 18),
                    onTap: e.value.onTap,
                  ),
                  if (!isLast)
                    const Divider(
                        height: 1,
                        indent: 56,
                        color: AppColors.lightBorder),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    ).animate().fadeIn();
  }
}

// ── Security & Privacy Sheet ──────────────────────────────────────────────────

class _SecuritySheet extends ConsumerStatefulWidget {
  const _SecuritySheet();

  @override
  ConsumerState<_SecuritySheet> createState() => _SecuritySheetState();
}

class _SecuritySheetState extends ConsumerState<_SecuritySheet> {
  bool _loading = false;
  String? _error;

  Future<void> _changePassword() async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تغيير كلمة المرور'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: oldCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                      hintText: 'كلمة المرور الحالية')),
              const SizedBox(height: 10),
              TextField(
                  controller: newCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                      hintText: 'كلمة المرور الجديدة')),
              const SizedBox(height: 10),
              TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                      hintText: 'تأكيد كلمة المرور')),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    if (newCtrl.text.length < 8) {
      setState(() => _error = 'كلمة المرور الجديدة قصيرة');
      return;
    }
    if (newCtrl.text != confirmCtrl.text) {
      setState(() => _error = 'كلمتا المرور غير متطابقتين');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final user = ref.read(authProvider).user;
      if (user == null) throw Exception('no user');
      final cred = EmailAuthProvider.credential(
          email: user.email!, password: oldCtrl.text);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم تغيير كلمة المرور ✓',
                  textAlign: TextAlign.right)),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyAuthError(e.code));
    } catch (_) {
      setState(() => _error = 'تعذّر تغيير كلمة المرور');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuthError(String code) {
    return switch (code) {
      'wrong-password' => 'كلمة المرور الحالية خاطئة',
      'weak-password' => 'كلمة المرور الجديدة ضعيفة',
      _ => 'حدث خطأ. حاول مجدداً.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('الأمان والخصوصية',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SecurityTile(
              icon: Icons.lock_outline,
              title: 'تغيير كلمة المرور',
              subtitle: 'اختر كلمة مرور قوية وآمنة',
              onTap: _loading ? null : _changePassword,
            ),
            const SizedBox(height: 12),
            _SecurityTile(
              icon: Icons.visibility_off_outlined,
              title: 'إخفاء المعلومات الشخصية',
              subtitle: 'لا يتم مشاركة البيانات مع أطراف ثالثة',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('مفعّل بشكل افتراضي ✓',
                          textAlign: TextAlign.right)),
                );
              },
            ),
            const SizedBox(height: 12),
            _SecurityTile(
              icon: Icons.delete_outline,
              title: 'حذف بيانات التصفح',
              subtitle: 'مسح سجل الاستهلاك والفواتير من الجهاز',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('تم مسح البيانات المؤقتة ✓',
                          textAlign: TextAlign.right)),
                );
              },
              color: AppColors.error,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ],
            if (_loading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

class _SecurityTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  final Color? color;
  const _SecurityTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lightBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (color ?? AppColors.primary).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon,
                  size: 20, color: color ?? AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.lightMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left,
                color: AppColors.lightMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Help & Support Sheet ──────────────────────────────────────────────────────

class _HelpSheet extends StatelessWidget {
  const _HelpSheet();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('المساعدة والدعم',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _HelpTile(
              icon: Icons.info_outline,
              title: 'كيفية استخدام التطبيق',
              body: 'التطبيق يمكنك من متابعة حالة المولد، مشاهدة الفواتير، وإرسال وصل الدفع.',
            ),
            const SizedBox(height: 12),
            _HelpTile(
              icon: Icons.payment_outlined,
              title: 'كيف أدفع الفاتورة؟',
              body: 'اذهب إلى تب الفواتير، اضغط على «ارسال وصل»، وارفع صورة إيصال الدفع للمراجعة.',
            ),
            const SizedBox(height: 12),
            _HelpTile(
              icon: Icons.report_problem_outlined,
              title: 'التقار من مشكلة',
              body:
                  'إذا واجهتك مشكلة فنية، يرجى التواصل مع صاحب المولد مباشرة أو ارسال شكوى من تب الشكاوى.',
            ),
            const SizedBox(height: 12),
            _HelpTile(
              icon: Icons.phone_outlined,
              title: 'تواصل مع المشرف',
              body:
                  'يمكنك التواصل مع صاحب المولد مباشرة لحل أي مشكلة تتعلق بالتشغيل أو الفواتير.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.email_outlined,
                      size: 18, color: AppColors.primary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'الدعم: support@powershare.app',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _HelpTile(
      {required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(body,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.lightMuted,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SettingsItem(this.icon, this.label, this.color, this.onTap);
}

// ── Theme Toggle Card ─────────────────────────────────────────────────────────

class _ThemeToggleCard extends StatelessWidget {
  final bool isDark;
  final WidgetRef ref;
  const _ThemeToggleCard({required this.isDark, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8, right: 4),
          child: Text('المظهر',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.lightMuted)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            title: Text(
              isDark ? 'الوضع الداكن' : 'الوضع الفاتح',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              isDark ? 'اضغط للتبديل للوضع الفاتح' : 'اضغط للتبديل للوضع الداكن',
              style: const TextStyle(fontSize: 11, color: AppColors.lightMuted),
            ),
            trailing: Switch(
              value: isDark,
              onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
              activeColor: AppColors.primary,
            ),
            onTap: () => ref.read(themeProvider.notifier).toggle(),
          ),
        ),
      ],
    ).animate().fadeIn();
  }
}

// ── Logout Button ─────────────────────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  final WidgetRef ref;
  final BuildContext context;
  const _LogoutButton({required this.ref, required this.context});

  @override
  Widget build(BuildContext buildContext) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          await ref.read(authProvider.notifier).signOut();
          if (context.mounted) context.go('/login');
        },
        icon: const Icon(Icons.logout, size: 18, color: AppColors.error),
        label: const Text('تسجيل الخروج',
            style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
                fontSize: 15)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: AppColors.error, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ).animate().fadeIn();
  }
}

// ── Complaint Submission Sheet ────────────────────────────────────────────────

class _ComplaintSheet extends ConsumerStatefulWidget {
  const _ComplaintSheet();

  @override
  ConsumerState<_ComplaintSheet> createState() => _ComplaintSheetState();
}

class _ComplaintSheetState extends ConsumerState<_ComplaintSheet> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'يرجى كتابة نص الشكوى');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final profile = ref.read(authProvider).profile;
      if (profile == null) throw Exception('no profile');
      await FirebaseService().addComplaint(profile.uid, profile.name, text);
      await NotificationService().notifyAdminNewComplaint(profile.name);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم إرسال الشكوى ✓', textAlign: TextAlign.right)),
        );
      }
    } catch (_) {
      setState(() { _error = 'تعذّر إرسال الشكوى. حاول مجدداً.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.report_problem_outlined,
                      color: AppColors.error, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('إرسال شكوى',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'صِف مشكلتك بوضوح وسيتم الرد عليك في أقرب وقت.',
              style: TextStyle(fontSize: 13, color: AppColors.lightMuted),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              maxLines: 5,
              autofocus: true,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'اكتب شكواك هنا...',
                hintStyle: const TextStyle(color: AppColors.lightMuted),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.lightBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.lightBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2)),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(
                      color: AppColors.error, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Icon(Icons.send_outlined, size: 18),
                label: Text(_loading ? 'جارٍ الإرسال...' : 'إرسال الشكوى'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── My Complaints Sheet ───────────────────────────────────────────────────────

class _MyComplaintsSheet extends ConsumerWidget {
  final String uid;
  const _MyComplaintsSheet({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complaintsAsync = ref.watch(consumerComplaintsProvider(uid));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.history_outlined,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('شكاواي',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: complaintsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(
                    child: Text('تعذّر تحميل الشكاوى')),
                data: (complaints) => complaints.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 52,
                                color:
                                    AppColors.success.withOpacity(0.7)),
                            const SizedBox(height: 12),
                            const Text('لا توجد شكاوى مقدَّمة',
                                style: TextStyle(
                                    fontSize: 15,
                                    color: AppColors.lightMuted)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: complaints.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, i) =>
                            _ConsumerComplaintCard(complaint: complaints[i]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsumerComplaintCard extends StatelessWidget {
  final Complaint complaint;
  const _ConsumerComplaintCard({required this.complaint});

  Color get _statusColor => switch (complaint.status) {
        ComplaintStatus.open => AppColors.error,
        ComplaintStatus.inProgress => AppColors.warning,
        _ => AppColors.success,
      };

  String get _statusLabel => switch (complaint.status) {
        ComplaintStatus.open => 'مفتوح',
        ComplaintStatus.inProgress => 'قيد المعالجة',
        _ => 'تمت المعالجة',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasReply =
        complaint.reply != null && complaint.reply!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${complaint.createdAt.day}/${complaint.createdAt.month}/${complaint.createdAt.year}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.lightMuted),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(_statusLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(complaint.text,
              style: const TextStyle(fontSize: 14, height: 1.4)),
          if (hasReply) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.success.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.reply_outlined,
                          size: 15, color: AppColors.success),
                      SizedBox(width: 6),
                      Text('رد المولد',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(complaint.reply!,
                      style: const TextStyle(
                          fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
