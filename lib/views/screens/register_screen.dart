import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../theme/portal_tokens.dart';
import '../widgets/portal_components.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  UserRole _role = UserRole.consumer;
  final _idCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _passVisible = false;
  bool _loading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = _idCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (id.length < 9 || !RegExp(r'^\d+$').hasMatch(id)) {
      setState(() =>
          _errorMsg = 'رقم الهوية يجب أن يكون أرقاماً (9-10 خانات على الأقل)');
      return;
    }
    if (name.isEmpty) {
      setState(() => _errorMsg = 'الرجاء إدخال الاسم');
      return;
    }
    if (pass.length < 8) {
      setState(() => _errorMsg = 'كلمة المرور يجب أن تكون 8 أحرف على الأقل');
      return;
    }
    if (pass != confirm) {
      setState(() => _errorMsg = 'كلمتا المرور غير متطابقتين');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final error = await ref.read(authProvider.notifier).register(
          idNumber: id,
          name: name,
          address: address,
          password: pass,
          role: _role,
        );

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      setState(() => _errorMsg = error);
    } else {
      final msg = _role == UserRole.admin
          ? 'تم تقديم طلبك بنجاح.\nيُرجى انتظار موافقة المشرف العام للدخول.'
          : 'تم تقديم طلبك بنجاح.\nيُرجى انتظار موافقة صاحب المولد للدخول.';
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            scrollable: true,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PortalTokens.radiusPanel)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: PortalTone.success.colors(context).$2,
                      shape: BoxShape.circle),
                  child: Icon(Icons.check_circle,
                      size: 48, color: PortalTone.success.colors(context).$1),
                ),
                const SizedBox(height: 16),
                Text('تم تقديم الطلب!',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(msg,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5)),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/login');
                  },
                  child: const Text('حسناً، سأنتظر'),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nameHint = _role == UserRole.admin ? 'اسم المولد' : 'الاسم الكامل';

    return PortalPage(
        title: 'بوابة المولدات',
        subtitle: 'إنشاء حساب جديد',
        reserveNavigation: false,
        children: [
          Text('سيتم مراجعة طلبك قبل التفعيل',
              style: theme.textTheme.bodyMedium),
          const PortalSection('نوع الحساب'),
          _RoleSwitch(
              selected: _role, onChanged: (r) => setState(() => _role = r)),
          const SizedBox(height: PortalTokens.xl),
          PortalPanel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const _SectionLabel('رقم الهوية'),
                const SizedBox(height: PortalTokens.sm),
                _Field(
                    controller: _idCtrl,
                    hint: 'xxxxxxxxxx',
                    icon: Icons.badge_outlined,
                    inputType: TextInputType.number,
                    formatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10)
                    ]),
                const SizedBox(height: PortalTokens.lg),
                _SectionLabel(nameHint),
                const SizedBox(height: PortalTokens.sm),
                _Field(
                    controller: _nameCtrl,
                    hint: nameHint,
                    icon: _role == UserRole.admin
                        ? Icons.bolt
                        : Icons.person_outline),
                const SizedBox(height: PortalTokens.lg),
                const _SectionLabel('العنوان'),
                const SizedBox(height: PortalTokens.sm),
                _Field(
                    controller: _addressCtrl,
                    hint: 'المدينة / الحي',
                    icon: Icons.location_on_outlined),
                const SizedBox(height: PortalTokens.lg),
                const _SectionLabel('كلمة المرور'),
                const SizedBox(height: PortalTokens.sm),
                _PasswordField(
                    controller: _passCtrl,
                    hint: '8 أحرف على الأقل',
                    visible: _passVisible,
                    onToggle: () =>
                        setState(() => _passVisible = !_passVisible)),
                const SizedBox(height: PortalTokens.lg),
                const _SectionLabel('تأكيد كلمة المرور'),
                const SizedBox(height: PortalTokens.sm),
                _PasswordField(
                    controller: _confirmCtrl,
                    hint: 'أعد كتابة كلمة المرور',
                    visible: _passVisible,
                    onToggle: () =>
                        setState(() => _passVisible = !_passVisible)),
                if (_errorMsg != null) ...[
                  const SizedBox(height: PortalTokens.lg),
                  PortalErrorState(_errorMsg!)
                ],
                const SizedBox(height: PortalTokens.xl),
                ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox.square(
                            dimension: PortalTokens.icon,
                            child: CircularProgressIndicator())
                        : const Text('تقديم الطلب')),
                const SizedBox(height: PortalTokens.lg),
                TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('لديك حساب؟ تسجيل الدخول')),
              ])),
        ]);
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      );
}

class _RoleSwitch extends StatelessWidget {
  final UserRole selected;
  final ValueChanged<UserRole> onChanged;
  const _RoleSwitch({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(PortalTokens.radius)),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _RoleTab(
              label: 'مستخدم',
              icon: Icons.person,
              selected: selected == UserRole.consumer,
              onTap: () => onChanged(UserRole.consumer)),
          const SizedBox(width: 4),
          _RoleTab(
              label: 'صاحب مولد',
              icon: Icons.bolt,
              selected: selected == UserRole.admin,
              onTap: () => onChanged(UserRole.admin)),
        ],
      ),
    );
  }
}

class _RoleTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _RoleTab(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
      child: Padding(
          padding: const EdgeInsets.all(PortalTokens.xs),
          child: Semantics(
              selected: selected,
              child: OutlinedButton.icon(
                  onPressed: onTap,
                  icon: Icon(selected ? Icons.check_circle_outline : icon),
                  label: Text(label),
                  style: OutlinedButton.styleFrom(
                      backgroundColor: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      side: BorderSide(
                          width: selected
                              ? PortalTokens.focusLine
                              : PortalTokens.line,
                          color: Theme.of(context).colorScheme.primary))))));
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType inputType;
  final List<TextInputFormatter>? formatters;
  const _Field(
      {required this.controller,
      required this.hint,
      required this.icon,
      this.inputType = TextInputType.text,
      this.formatters});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: inputType,
        inputFormatters: formatters,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          prefixIcon: Icon(icon,
              color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
          filled: true,
          fillColor: Theme.of(context).cardTheme.color,
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
                  color: Theme.of(context).colorScheme.primary, width: 2)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      );
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool visible;
  final VoidCallback onToggle;
  const _PasswordField(
      {required this.controller,
      required this.hint,
      required this.visible,
      required this.onToggle});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        obscureText: !visible,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          prefixIcon: Icon(Icons.lock_outline,
              color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
                visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            onPressed: onToggle,
          ),
          filled: true,
          fillColor: Theme.of(context).cardTheme.color,
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
                  color: Theme.of(context).colorScheme.primary, width: 2)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      );
}
