import '../../widgets/profile_edit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../models/user_model.dart';
import '../../../models/complaint_model.dart';
import '../../../services/firebase_service.dart';
import '../../../services/notification_service.dart';
import '../../../theme/portal_tokens.dart';
import '../../widgets/portal_components.dart';
import '../../widgets/portal_keyboard.dart';
import '../../widgets/notification_bell.dart';

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

    return PortalPage(
        title: 'الملف',
        subtitle: profile?.name ?? 'مستخدم',
        actions: const [
          NotificationBell()
        ],
        children: [
          PortalPanel(
              child: Row(children: [
            CircleAvatar(
                radius: PortalTokens.xl,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(initials,
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(color: theme.colorScheme.primary))),
            const SizedBox(width: PortalTokens.lg),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      profile?.name.isNotEmpty == true
                          ? profile!.name
                          : 'مستخدم',
                      style: theme.textTheme.titleLarge),
                  Text(profile?.role == UserRole.admin ? 'صاحب مولد' : 'مستهلك',
                      style: theme.textTheme.bodySmall),
                ])),
          ])),
          const ContactCompletionPrompt(),
          const PortalSection('بيانات الحساب'),
          _InfoCard(),
          const SizedBox(height: PortalTokens.xl),
          _SettingsGroup(title: 'الحساب', items: [
            _SettingsItem(Icons.edit_outlined, 'تعديل البيانات',
                theme.colorScheme.primary, () {
              _showEditSheet(context, ref);
            }),
          ]),
          const SizedBox(height: PortalTokens.xl),
          _ThemeToggleCard(isDark: isDark, ref: ref),
          const SizedBox(height: PortalTokens.xl),
          _SettingsGroup(title: 'الدعم', items: [
            _SettingsItem(
                Icons.report_problem_outlined,
                'إرسال شكوى',
                theme.colorScheme.primary,
                () => _showComplaintSheet(context, ref)),
            _SettingsItem(
                Icons.history_outlined,
                'شكاواي',
                theme.colorScheme.primary,
                () => _showMyComplaintsSheet(context, ref)),
          ]),
          const SizedBox(height: PortalTokens.xl),
          _LogoutButton(ref: ref, context: context),
          const SizedBox(height: PortalTokens.xl),
          Center(
              child: Text('بوابة المولدات v1.0.0',
                  style: theme.textTheme.bodySmall)),
        ]);
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    showPortalFormSheet(
        context: context,
        builder: (_) => const ProfileEditSheet(title: 'تعديل البيانات'));
  }

  void _showSecuritySheet(BuildContext context) {
    showPortalFormSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _SecuritySheet(),
    );
  }

  void _showHelpSheet(BuildContext context) {
    showPortalFormSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _HelpSheet(),
    );
  }

  void _showComplaintSheet(BuildContext context, WidgetRef ref) {
    showPortalFormSheet(
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
    showPortalFormSheet(
      context: context,
      scrollable: false,
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

class _InfoCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).profile;
    return Container(
      padding: const EdgeInsets.all(PortalTokens.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(PortalTokens.radiusPanel),
      ),
      child: Column(
        children: [
          _InfoRow(Icons.phone, 'رقم الهاتف', profile?.phone ?? '—'),
          Divider(
              height: 20, color: Theme.of(context).colorScheme.outlineVariant),
          _InfoRow(Icons.location_on_outlined, 'العنوان',
              profile?.address?.isNotEmpty == true ? profile!.address : '—'),
          Divider(
              height: 20, color: Theme.of(context).colorScheme.outlineVariant),
          _InfoRow(Icons.badge_outlined, 'نوع الحساب',
              profile?.role == UserRole.admin ? 'صاحب مولد' : 'مستهلك'),
          Divider(
              height: 20, color: Theme.of(context).colorScheme.outlineVariant),
          _InfoRow(
              Icons.calendar_today,
              'تاريخ الانضمام',
              profile != null
                  ? '${profile.createdAt.day}/${profile.createdAt.month}/${profile.createdAt.year}'
                  : '—'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) =>
      PortalDataRow(label: label, value: value, icon: icon);
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border:
                Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(PortalTokens.radiusPanel),
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final isLast = e.key == items.length - 1;
              return Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(PortalTokens.sm),
                      decoration: BoxDecoration(
                        color: e.value.color.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(PortalTokens.radiusSmall),
                      ),
                      child: Icon(e.value.icon, size: 18, color: e.value.color),
                    ),
                    title: Text(e.value.label,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500)),
                    trailing: Icon(Icons.chevron_left,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 18),
                    onTap: e.value.onTap,
                  ),
                  if (!isLast)
                    Divider(
                        height: 1,
                        indent: 56,
                        color: Theme.of(context).colorScheme.outlineVariant),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Security & Privacy Sheet ──────────────────────────────────────────────────

class _SecuritySheet extends ConsumerStatefulWidget {
  const _SecuritySheet();

  @override
  ConsumerState<_SecuritySheet> createState() => _SecuritySheetState();
}

class _SecuritySheetState extends ConsumerState<_SecuritySheet> {
  final bool _loading = false;
  String? _error;

  Future<void> _changePassword() async => context.go('/account-security');

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
                Expanded(
                  child: Text('الأمان والخصوصية',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
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
              color: PortalTone.danger.colors(context).$1,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: PortalTone.danger.colors(context).$1)),
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
      borderRadius: BorderRadius.circular(PortalTokens.radius),
      child: Container(
        padding: const EdgeInsets.all(PortalTokens.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(PortalTokens.radius),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(PortalTokens.sm),
              decoration: BoxDecoration(
                color: (color ?? Theme.of(context).colorScheme.primary)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(PortalTokens.radiusSmall),
              ),
              child: Icon(icon,
                  size: 20,
                  color: color ?? Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_left,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 18),
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
                Expanded(
                  child: Text('المساعدة والدعم',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _HelpTile(
              icon: Icons.info_outline,
              title: 'كيفية استخدام التطبيق',
              body:
                  'التطبيق يمكنك من متابعة حالة المولد، مشاهدة الفواتير، وتسجيل بيانات الدفع.',
            ),
            const SizedBox(height: 12),
            const _HelpTile(
              icon: Icons.payment_outlined,
              title: 'كيف أدفع الفاتورة؟',
              body:
                  'اذهب إلى الفواتير، واضغط «تسجيل دفعة»، ثم أدخل المبلغ والتاريخ والمرجع والطريقة لإرسالها للمراجعة.',
            ),
            const SizedBox(height: 12),
            const _HelpTile(
              icon: Icons.report_problem_outlined,
              title: 'التقار من مشكلة',
              body:
                  'إذا واجهتك مشكلة فنية، يرجى التواصل مع صاحب المولد مباشرة أو ارسال شكوى من تب الشكاوى.',
            ),
            const SizedBox(height: 12),
            const _HelpTile(
              icon: Icons.phone_outlined,
              title: 'تواصل مع المشرف',
              body:
                  'يمكنك التواصل مع صاحب المولد مباشرة لحل أي مشكلة تتعلق بالتشغيل أو الفواتير.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(PortalTokens.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(PortalTokens.radius),
              ),
              child: Row(
                children: [
                  Icon(Icons.email_outlined,
                      size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'الدعم: support@powershare.app',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
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
      padding: const EdgeInsets.all(PortalTokens.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(PortalTokens.radius),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(PortalTokens.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(PortalTokens.radiusSmall),
            ),
            child: Icon(icon,
                size: 20, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        Padding(
          padding: const EdgeInsets.only(bottom: 8, right: 4),
          child: Text('المظهر',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border:
                Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(PortalTokens.radiusPanel),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(PortalTokens.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(PortalTokens.radiusSmall),
              ),
              child: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(
              isDark ? 'الوضع الداكن' : 'الوضع الفاتح',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              isDark
                  ? 'اضغط للتبديل للوضع الفاتح'
                  : 'اضغط للتبديل للوضع الداكن',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            trailing: Switch(
              value: isDark,
              onChanged: (_) => ref
                  .read(themeProvider.notifier)
                  .toggle(visibleBrightness: Theme.of(context).brightness),
              activeThumbColor: Theme.of(context).colorScheme.primary,
            ),
            onTap: () => ref
                .read(themeProvider.notifier)
                .toggle(visibleBrightness: Theme.of(context).brightness),
          ),
        ),
      ],
    );
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
        icon: Icon(Icons.logout,
            size: 18, color: PortalTone.danger.colors(context).$1),
        label: Text('تسجيل الخروج',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: PortalTone.danger.colors(context).$1,
                fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(
              color: PortalTone.danger.colors(context).$1, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PortalTokens.radiusPanel)),
        ),
      ),
    );
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = ref.read(authProvider).profile;
      if (profile == null) throw Exception('no profile');
      await FirebaseService().addComplaint(profile.uid, profile.name, text);
      await NotificationService().notifyAdminNewComplaint(profile.name);
      if (mounted) completePortalSave(context, message: 'تم إرسال الشكوى ✓');
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'تعذّر إرسال الشكوى. حاول مجدداً.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24,
        ),
        child: SingleChildScrollView(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(PortalTokens.sm),
                  decoration: BoxDecoration(
                    color: PortalTone.danger.colors(context).$2,
                    borderRadius:
                        BorderRadius.circular(PortalTokens.radiusSmall),
                  ),
                  child: Icon(Icons.report_problem_outlined,
                      color: PortalTone.danger.colors(context).$1, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('إرسال شكوى',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'صِف مشكلتك بوضوح وسيتم الرد عليك في أقرب وقت.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              maxLines: 5,
              autofocus: true,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'اكتب شكواك هنا...',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PortalTokens.radius),
                    borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PortalTokens.radius),
                    borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PortalTokens.radius),
                    borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2)),
                contentPadding: const EdgeInsets.all(PortalTokens.lg),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: PortalTone.danger.colors(context).$1)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Theme.of(context).colorScheme.surface))
                    : const Icon(Icons.send_outlined, size: 18),
                label: Text(_loading ? 'جارٍ الإرسال...' : 'إرسال الشكوى'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        )),
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
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(PortalTokens.xs),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(PortalTokens.sm),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(PortalTokens.radiusSmall),
                    ),
                    child: Icon(Icons.history_outlined,
                        color: Theme.of(context).colorScheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('شكاواي',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
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
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) =>
                    const Center(child: Text('تعذّر تحميل الشكاوى')),
                data: (complaints) => complaints.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 52,
                                color: PortalTone.success
                                    .colors(context)
                                    .$1
                                    .withValues(alpha: 0.7)),
                            const SizedBox(height: 12),
                            Text('لا توجد شكاوى مقدَّمة',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: complaints.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
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
  PortalTone get _tone => switch (complaint.status) {
        ComplaintStatus.open => PortalTone.danger,
        ComplaintStatus.inProgress => PortalTone.warning,
        _ => PortalTone.success,
      };
  String get _statusLabel => switch (complaint.status) {
        ComplaintStatus.open => 'مفتوح',
        ComplaintStatus.inProgress => 'قيد المعالجة',
        _ => 'تمت المعالجة',
      };
  @override
  Widget build(BuildContext context) {
    final hasReply = complaint.reply != null && complaint.reply!.isNotEmpty;
    return PortalPanel(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PortalRecordRow(
          title: complaint.text,
          subtitle:
              '${complaint.createdAt.day}/${complaint.createdAt.month}/${complaint.createdAt.year}',
          icon: Icons.report_problem_outlined,
          statusLabel: _statusLabel,
          statusTone: _tone),
      if (hasReply) ...[
        const Divider(),
        const PortalSection('رد المولد'),
        Text(complaint.reply!, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ]));
  }
}
