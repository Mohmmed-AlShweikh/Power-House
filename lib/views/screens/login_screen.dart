import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../config/colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  UserRole _role = UserRole.consumer;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _submit() async {
    final digits = _phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) return;

    // Demo bypass codes
    if (digits == '0000000000') {
      ref.read(authProvider.notifier).demoLogin(UserRole.consumer);
      if (mounted) context.go('/consumer');
      return;
    }
    if (digits == '9999999999') {
      ref.read(authProvider.notifier).demoLogin(UserRole.admin);
      if (mounted) context.go('/admin');
      return;
    }

    setState(() { _loading = true; _errorMsg = null; });
    final sent = await ref.read(authProvider.notifier).sendOtp(digits, context);
    if (!mounted) return;

    final error = ref.read(authProvider).error;
    setState(() { _loading = false; _errorMsg = error; });

    if (sent && error == null) context.push('/otp');
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final digits = _phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
    final isDemo = digits == '0000000000' || digits == '9999999999';
    final isValid = digits.length >= 9;

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
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
                                    color: Colors.white60,
                                    fontSize: 12,
                                    letterSpacing: 0.8)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('مرحباً بك!',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text('سجّل دخولك للمتابعة',
                        style: TextStyle(color: Colors.white60, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),

          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('نوع الحساب'),
                        const SizedBox(height: 10),
                        _RoleToggle(
                          selected: _role,
                          onChanged: (v) => setState(() => _role = v),
                        ),
                        const SizedBox(height: 20),
                        _Label('رقم الهاتف'),
                        const SizedBox(height: 8),
                        _PhoneInput(
                          controller: _phoneCtrl,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: _submit,
                        ),
                        const SizedBox(height: 6),
                        Text('مثال: 0591234567',
                            style: theme.textTheme.labelLarge),
                        if (isDemo) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.success.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Text('🎭',
                                    style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'وضع المعاينة — ${digits == '9999999999' ? 'صاحب مولد' : 'مستهلك'}',
                                    style: const TextStyle(
                                        color: AppColors.success,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_errorMsg != null) ...[
                          const SizedBox(height: 12),
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
                                  child: Text(
                                    _errorMsg!,
                                    style: const TextStyle(
                                        color: AppColors.error,
                                        fontSize: 13,
                                        height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loading || !isValid ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Colors.white),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(isDemo ? 'دخول المعاينة' : 'متابعة'),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_back, size: 18),
                                  ],
                                ),
                        ).animate().fadeIn(delay: 200.ms),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      isDemo
                          ? 'أكواد المعاينة: 0000000000 (مستهلك) · 9999999999 (أدمن)'
                          : 'سيتم إرسال رمز التحقق على رقمك',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.lightText,
            ),
      );
}

class _RoleToggle extends StatelessWidget {
  final UserRole selected;
  final ValueChanged<UserRole> onChanged;
  const _RoleToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Container(
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _Tab(
              label: 'مستهلك',
              icon: Icons.person,
              selected: selected == UserRole.consumer,
              onTap: () => onChanged(UserRole.consumer)),
          const SizedBox(width: 4),
          _Tab(
              label: 'صاحب مولد',
              icon: Icons.settings,
              selected: selected == UserRole.admin,
              onTap: () => onChanged(UserRole.admin)),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _Tab(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
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
                  color: selected ? Colors.white : AppColors.lightMuted),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.lightMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneInput extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  const _PhoneInput(
      {required this.controller, this.onChanged, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border.all(color: AppColors.lightBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Text('🇵🇸', style: TextStyle(fontSize: 18)),
                SizedBox(width: 6),
                Text('+972',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lightText)),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              textDirection: TextDirection.ltr,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmitted?.call(),
              style: const TextStyle(fontSize: 16, letterSpacing: 1.2),
              decoration: const InputDecoration(
                hintText: '05xxxxxxxx',
                hintStyle:
                    TextStyle(color: AppColors.lightMuted, letterSpacing: 0.5),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
