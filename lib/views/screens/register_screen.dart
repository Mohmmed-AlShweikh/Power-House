import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../config/colors.dart';

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
      setState(() => _errorMsg = 'رقم الهوية يجب أن يكون أرقاماً (9-10 خانات على الأقل)');
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

    setState(() { _loading = true; _errorMsg = null; });

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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle,
                      size: 48, color: AppColors.success),
                ),
                const SizedBox(height: 16),
                const Text('تم تقديم الطلب!',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(msg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.lightMuted,
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

    return Scaffold(
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.bolt,
                              color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('بوابة المولدات',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800)),
                            Text('Generator Portal',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('إنشاء حساب جديد',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text('سيتم مراجعة طلبك قبل التفعيل',
                        style: TextStyle(
                            color: Colors.white60, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Role selection
                  _SectionLabel('نوع الحساب'),
                  const SizedBox(height: 10),
                  _RoleSwitch(
                    selected: _role,
                    onChanged: (r) => setState(() => _role = r),
                  ),
                  const SizedBox(height: 20),

                  // Form
                  _SectionLabel('رقم الهوية'),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _idCtrl,
                    hint: 'xxxxxxxxxx',
                    icon: Icons.badge_outlined,
                    inputType: TextInputType.number,
                    formatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _SectionLabel(nameHint),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _nameCtrl,
                    hint: nameHint,
                    icon: _role == UserRole.admin
                        ? Icons.bolt
                        : Icons.person_outline,
                  ),
                  const SizedBox(height: 16),

                  _SectionLabel('العنوان'),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _addressCtrl,
                    hint: 'المدينة / الحي',
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 16),

                  _SectionLabel('كلمة المرور'),
                  const SizedBox(height: 8),
                  _PasswordField(
                    controller: _passCtrl,
                    hint: '8 أحرف على الأقل',
                    visible: _passVisible,
                    onToggle: () =>
                        setState(() => _passVisible = !_passVisible),
                  ),
                  const SizedBox(height: 16),

                  _SectionLabel('تأكيد كلمة المرور'),
                  const SizedBox(height: 8),
                  _PasswordField(
                    controller: _confirmCtrl,
                    hint: 'أعد كتابة كلمة المرور',
                    visible: _passVisible,
                    onToggle: () =>
                        setState(() => _passVisible = !_passVisible),
                  ),

                  if (_errorMsg != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.error.withOpacity(0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 18, color: AppColors.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_errorMsg!,
                                style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 13,
                                    height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : const Text('تقديم الطلب'),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/login'),
                      child: RichText(
                        text: const TextSpan(
                          text: 'لديك حساب؟ ',
                          style: TextStyle(color: AppColors.lightMuted),
                          children: [
                            TextSpan(
                              text: 'تسجيل الدخول',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.lightText,
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
          borderRadius: BorderRadius.circular(12)),
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
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: 200.ms,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 17,
                    color:
                        selected ? Colors.white : AppColors.lightMuted),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : AppColors.lightMuted)),
              ],
            ),
          ),
        ),
      );
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
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.lightMuted),
          prefixIcon:
              Icon(icon, color: AppColors.lightMuted, size: 20),
          filled: true,
          fillColor: Theme.of(context).cardTheme.color,
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
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 14),
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
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.lightMuted),
          prefixIcon: const Icon(Icons.lock_outline,
              color: AppColors.lightMuted, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
                visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: AppColors.lightMuted),
            onPressed: onToggle,
          ),
          filled: true,
          fillColor: Theme.of(context).cardTheme.color,
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
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 14),
        ),
      );
}
