import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../models/user_model.dart';
import '../../../config/colors.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).profile;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode,
                    color: Colors.white),
                onPressed: () => ref.read(themeProvider.notifier).toggle(),
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
                      Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 2),
                            ),
                            child:
                                const Icon(Icons.person, size: 44, color: Colors.white),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt,
                                  size: 13, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(profile?.name.isNotEmpty == true ? profile!.name : 'مستخدم',
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
                          profile?.role == UserRole.admin ? 'صاحب مولد' : 'مستهلك',
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
                _SettingsGroup(title: 'الإعدادات', items: [
                  _SettingsItem(Icons.security, 'الأمان والخصوصية',
                      AppColors.primary, () {}),
                  _SettingsItem(Icons.help_outline, 'المساعدة والدعم',
                      AppColors.primary, () {}),
                ]),
                const SizedBox(height: 12),
                _SettingsGroup(title: 'الحساب', items: [
                  _SettingsItem(Icons.edit_outlined, 'تعديل البيانات',
                      AppColors.warning, () {
                    _showEditSheet(context, ref);
                  }),
                  _SettingsItem(Icons.logout, 'تسجيل الخروج', AppColors.error,
                      () async {
                    await ref.read(authProvider.notifier).signOut();
                    if (context.mounted) context.go('/login');
                  }),
                ]),
                const SizedBox(height: 20),
                Center(
                  child: Text('بوابة المولدات v1.0.0',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.lightMuted.withOpacity(0.6))),
                ),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    final profile = ref.read(authProvider).profile;
    final nameCtrl =
        TextEditingController(text: profile?.name ?? '');
    final addressCtrl =
        TextEditingController(text: profile?.address ?? '');

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
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  const _SheetField(
      {required this.controller, required this.hint, required this.icon});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
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

class _SettingsItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SettingsItem(this.icon, this.label, this.color, this.onTap);
}
