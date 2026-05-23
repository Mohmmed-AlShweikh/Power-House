import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../config/colors.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});
  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _loading = false;

  void _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    await ref.read(authProvider.notifier).updateProfile(
          name: name,
          address: _addressCtrl.text.trim(),
        );
    setState(() => _loading = false);
    if (!mounted) return;
    final role = ref.read(authProvider).profile?.role;
    if (role == UserRole.admin)
      context.go('/admin');
    else
      context.go('/consumer');
  }

  void _skip() {
    final role = ref.read(authProvider).profile?.role;
    if (role == UserRole.admin)
      context.go('/admin');
    else
      context.go('/consumer');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // Header
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
                    Text('إعداد الملف',
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('اكتمل الخطوة الأخيرة',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.white60)),
                    const SizedBox(height: 16),
                    _ProgressBar(),
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
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AvatarPicker(),
                        const SizedBox(height: 24),
                        _Label('الاسم الكامل *'),
                        const SizedBox(height: 8),
                        _Field(
                            controller: _nameCtrl,
                            hint: 'محمد أحمد',
                            icon: Icons.person_outline),
                        const SizedBox(height: 16),
                        _Label('العنوان'),
                        const SizedBox(height: 8),
                        _Field(
                            controller: _addressCtrl,
                            hint: 'رام الله، حي البيرة',
                            icon: Icons.location_on_outlined),
                        const SizedBox(height: 28),
                        ElevatedButton(
                          onPressed: _loading ? null : _save,
                          child: _loading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Colors.white))
                              : const Text('حفظ والمتابعة'),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton(
                            onPressed: _skip,
                            child: const Text('تخطي الآن'),
                          ),
                        ),
                      ],
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

class _ProgressBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepDot(label: '1', done: true),
        _Line(done: true),
        _StepDot(label: '2', done: true),
        _Line(done: false),
        _StepDot(label: '3', done: false, active: true),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool done;
  final bool active;
  const _StepDot(
      {required this.label, required this.done, this.active = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? AppColors.accent
            : active
                ? Colors.white
                : Colors.white.withOpacity(0.3),
      ),
      child: Center(
        child: done
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? AppColors.primary : Colors.white70)),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final bool done;
  const _Line({required this.done});
  @override
  Widget build(BuildContext context) => Expanded(
      child: Container(
          height: 2,
          color: done ? AppColors.accent : Colors.white.withOpacity(0.3)));
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
                offset: const Offset(0, 4)),
          ],
        ),
        child: child,
      );
}

class _AvatarPicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.lightBackground,
            ),
            child:
                const Icon(Icons.person, size: 44, color: AppColors.lightMuted),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
              child:
                  const Icon(Icons.camera_alt, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(color: AppColors.lightText));
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  const _Field(
      {required this.controller, required this.hint, required this.icon});

  @override
  Widget build(BuildContext context) {
    return TextField(
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
            borderSide: const BorderSide(color: AppColors.lightBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.lightBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
