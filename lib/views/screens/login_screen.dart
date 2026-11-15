import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../theme/portal_tokens.dart';
import '../widgets/portal_components.dart';

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
            scrollable: true,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PortalTokens.radiusPanel)),
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
          scrollable: true,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PortalTokens.radiusPanel)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_reset_outlined,
                    size: 40, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 14),
              Text(
                'إعادة تعيين كلمة المرور',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'يرجى التواصل مع الإدارة أو صاحب المولد لإعادة تعيين كلمة المرور \u201c${id.length > 6 ? id.substring(0, 3) + '****' + id.substring(id.length - 3) : id}\u201c.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5),
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

  @override
  Widget build(BuildContext context) {
    // Show error from provider (e.g. after status check redirect)
    final providerError = ref.watch(authProvider).error;
    final displayError = _errorMsg ?? providerError;

    return PortalPage(
        title: 'بوابة المولدات',
        subtitle: 'تسجيل الدخول',
        reserveNavigation: false,
        children: [
          const PortalSection('مرحباً بك!'),
          Text('سجّل دخولك برقم هويتك وكلمة المرور',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: PortalTokens.xl),
          _Card(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const _Label('رقم الهوية'),
                const SizedBox(height: PortalTokens.sm),
                TextField(
                    controller: _idCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10)
                    ],
                    style: Theme.of(context).textTheme.bodyLarge,
                    onSubmitted: (_) => _submit(),
                    decoration:
                        _fieldDecor('xxxxxxxxxx', Icons.badge_outlined)),
                const SizedBox(height: PortalTokens.xl),
                const _Label('كلمة المرور'),
                const SizedBox(height: PortalTokens.sm),
                TextField(
                    controller: _passCtrl,
                    obscureText: !_passVisible,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: _fieldDecor('••••••••', Icons.lock_outline)
                        .copyWith(
                            suffixIcon: IconButton(
                                tooltip: _passVisible
                                    ? 'إخفاء كلمة المرور'
                                    : 'إظهار كلمة المرور',
                                icon: Icon(_passVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                onPressed: () => setState(
                                    () => _passVisible = !_passVisible)))),
                if (displayError != null) ...[
                  const SizedBox(height: PortalTokens.lg),
                  PortalErrorState(displayError)
                ],
                const SizedBox(height: PortalTokens.sm),
                Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                        onPressed: _loading ? null : _forgotPassword,
                        child: const Text('نسيت كلمة المرور؟'))),
                const SizedBox(height: PortalTokens.lg),
                ElevatedButton(
                    onPressed: (_loading ||
                            _idCtrl.text.trim().isEmpty ||
                            _passCtrl.text.isEmpty)
                        ? null
                        : _submit,
                    child: _loading
                        ? const SizedBox.square(
                            dimension: PortalTokens.icon,
                            child: CircularProgressIndicator())
                        : const Text('تسجيل الدخول')),
                const SizedBox(height: PortalTokens.md),
                TextButton(
                    onPressed: () => context.go('/register'),
                    child: const Text('ليس لديك حساب؟ سجّل الآن')),
              ])),
        ]);
  }

  InputDecoration _fieldDecor(String hint, IconData icon) {
    return InputDecoration(hintText: hint, prefixIcon: Icon(icon));
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => PortalPanel(child: child);
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
