import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _passVisible = false;
  bool _loading = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _idCtrl.addListener(() => setState(() {}));
    _passCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _forgotPassword() async {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('نسيت كلمة المرور؟'),
            content: const Text('يرجى إدخال رقم هويتك أولاً في الحقل أعلاه.'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً'),
              ),
            ],
          ),
        ),
      );
      return;
    }

    // Show informational dialog — in-app reset handled by admin
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_reset_outlined,
                    size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 14),
              const Text(
                'إعادة تعيين كلمة المرور',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'يرجى التواصل مع الإدارة أو صاحب المولد لإعادة تعيين كلمة المرور \u201c${id.length > 6 ? id.substring(0, 3) + '****' + id.substring(id.length - 3) : id}\u201c.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.lightMuted, height: 1.5),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final id = _idCtrl.text.trim();
    final pass = _passCtrl.text;
    if (id.isEmpty || pass.isEmpty) return;

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final error = await ref.read(authProvider.notifier).login(id, pass);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _errorMsg = error;
    });

    if (error == null) {
      // Router handles redirect based on role
    }
  }

  Future<void> _demoLogin(UserRole role) async {
    await ref.read(authProvider.notifier).demoLogin(role);
    final path = switch (role) {
      UserRole.superAdmin => '/super_admin',
      UserRole.admin => '/admin',
      _ => '/consumer',
    };
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Show error from provider (e.g. after status check redirect)
    final providerError = ref.watch(authProvider).error;
    final displayError = _errorMsg ?? providerError;

    return Scaffold(
      body: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.primaryDarkFor(Theme.of(context).brightness),
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
                    const Text('سجّل دخولك برقم هويتك وكلمة المرور',
                        style: TextStyle(color: Colors.white60, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),

          // ── Form ─────────────────────────────────────────────────────────
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
                        _Label('رقم الهوية'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _idCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          style:
                              const TextStyle(fontSize: 16, letterSpacing: 1.0),
                          onSubmitted: (_) => _submit(),
                          decoration:
                              _fieldDecor('xxxxxxxxxx', Icons.badge_outlined),
                        ),
                        const SizedBox(height: 16),
                        _Label('كلمة المرور'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passCtrl,
                          obscureText: !_passVisible,
                          style: const TextStyle(fontSize: 16),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          decoration: _fieldDecor(
                            '••••••••',
                            Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _passVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                  color: AppColors.lightMuted),
                              onPressed: () =>
                                  setState(() => _passVisible = !_passVisible),
                            ),
                          ),
                        ),
                        if (displayError != null) ...[
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
                                  child: Text(displayError,
                                      style: const TextStyle(
                                          color: AppColors.error,
                                          fontSize: 13,
                                          height: 1.4)),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _loading ? null : _forgotPassword,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'نسيت كلمة المرور؟',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: (_loading ||
                                  _idCtrl.text.trim().isEmpty ||
                                  _passCtrl.text.isEmpty)
                              ? null
                              : _submit,
                          child: _loading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Colors.white))
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('تسجيل الدخول'),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_back, size: 18),
                                  ],
                                ),
                        ).animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () => context.go('/register'),
                            child: RichText(
                              text: const TextSpan(
                                text: 'ليس لديك حساب؟ ',
                                style: TextStyle(
                                    color: AppColors.lightMuted,
                                    fontFamily: 'Tajawal'),
                                children: [
                                  TextSpan(
                                    text: 'سجّل الآن',
                                    style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Tajawal'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Demo Section ─────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('🎭', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            const Text('وضع المعاينة',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                            const Spacer(),
                            Text('بدون Firebase',
                                style: TextStyle(
                                    color: AppColors.primary.withOpacity(0.6),
                                    fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _DemoBtn(
                              label: 'مستخدم',
                              icon: Icons.person,
                              color: AppColors.success,
                              onTap: () async =>
                                  await _demoLogin(UserRole.consumer),
                            ),
                            const SizedBox(width: 8),
                            _DemoBtn(
                              label: 'صاحب مولد',
                              icon: Icons.bolt,
                              color: AppColors.primary,
                              onTap: () async =>
                                  await _demoLogin(UserRole.admin),
                            ),
                            const SizedBox(width: 8),
                            _DemoBtn(
                              label: 'مشرف عام',
                              icon: Icons.admin_panel_settings,
                              color: const Color(0xFF9c27b0),
                              onTap: () async =>
                                  await _demoLogin(UserRole.superAdmin),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 400.ms),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecor(String hint, IconData icon) {
    final color = Theme.of(context).colorScheme.onSurface;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: color.withOpacity(0.65)),
      prefixIcon: Icon(icon, color: color.withOpacity(0.75), size: 20),
      filled: true,
      fillColor: Theme.of(context).scaffoldBackgroundColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color.withOpacity(0.15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color.withOpacity(0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

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
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Text(text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color));
  }
}

class _DemoBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _DemoBtn(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
          ),
        ),
      );
}
