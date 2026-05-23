import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../config/colors.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});
  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _ctrls = List.generate(6, (_) => TextEditingController());
  final _nodes = List.generate(6, (_) => FocusNode());
  int _seconds = 60;
  Timer? _timer;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nodes[0].requestFocus());
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds == 0) { t.cancel(); return; }
      if (mounted) setState(() => _seconds--);
    });
  }

  void _onChanged(String val, int idx) {
    if (val.isNotEmpty && idx < 5) _nodes[idx + 1].requestFocus();
    else if (val.isEmpty && idx > 0) _nodes[idx - 1].requestFocus();
  }

  void _verify() async {
    final code = _ctrls.map((c) => c.text).join();
    if (code.length < 6) return;
    setState(() => _loading = true);
    await ref.read(authProvider.notifier).verifyOtp(code);
    setState(() => _loading = false);
    if (!mounted) return;
    final state = ref.read(authProvider);
    if (state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('رمز خاطئ', textAlign: TextAlign.right)),
      );
      for (var c in _ctrls) c.clear();
      _nodes[0].requestFocus();
      return;
    }
    final role = state.profile?.role;
    if (role == UserRole.admin) context.go('/admin');
    else context.go('/consumer');
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrls) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phone = ref.watch(authProvider).phoneNumber;

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_forward, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('التحقق من الرقم',
                          style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white)),
                      Text('Verify Phone',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white60)),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _Card(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shield_outlined, size: 40, color: AppColors.primary),
                          )
                              .animate()
                              .scaleXY(begin: 0.8, end: 1, duration: 400.ms, curve: Curves.easeOutBack)
                              .fadeIn(),
                          const SizedBox(height: 16),
                          Text('أدخل رمز التحقق',
                              style: theme.textTheme.headlineSmall),
                          const SizedBox(height: 6),
                          Text(
                            'تم إرسال الرمز إلى +972${phone.replaceFirst('0', '')}',
                            style: theme.textTheme.labelLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),

                          // OTP boxes
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(
                                6,
                                (i) => SizedBox(
                                  width: 46,
                                  height: 56,
                                  child: TextField(
                                    controller: _ctrls[i],
                                    focusNode: _nodes[i],
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    maxLength: 1,
                                    onChanged: (v) => _onChanged(v, i),
                                    style: theme.textTheme.headlineSmall,
                                    decoration: InputDecoration(
                                      counterText: '',
                                      filled: true,
                                      fillColor: theme.scaffoldBackgroundColor,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppColors.lightBorder),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Timer
                          if (_seconds > 0)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.timer_outlined, size: 16, color: AppColors.lightMuted),
                                const SizedBox(width: 6),
                                Text('إعادة الإرسال بعد ${_seconds}s',
                                    style: theme.textTheme.labelLarge),
                              ],
                            )
                          else
                            TextButton(
                              onPressed: _startTimer,
                              child: const Text('إعادة إرسال الرمز'),
                            ),

                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _loading ? null : _verify,
                            child: _loading
                                ? const SizedBox(
                                    height: 22, width: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                : const Text('تحقق'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('تغيير رقم الهاتف',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: child,
      );
}
