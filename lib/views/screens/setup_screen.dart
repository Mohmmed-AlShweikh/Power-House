import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../theme/portal_tokens.dart';
import '../widgets/portal_components.dart';

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
    return Scaffold(
      body: Column(
        children: [
          // Header
          const PortalIdentityBar(
              title: 'إعداد الملف', subtitle: 'اكتمل الخطوة الأخيرة'),
          Padding(padding: PortalTokens.pagePadding, child: _ProgressBar()),

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
                        const _Label('الاسم الكامل *'),
                        const SizedBox(height: 8),
                        _Field(
                            controller: _nameCtrl,
                            hint: 'محمد أحمد',
                            icon: Icons.person_outline),
                        const SizedBox(height: 16),
                        const _Label('العنوان'),
                        const SizedBox(height: 8),
                        _Field(
                            controller: _addressCtrl,
                            hint: 'رام الله، حي البيرة',
                            icon: Icons.location_on_outlined),
                        const SizedBox(height: 28),
                        ElevatedButton(
                          onPressed: _loading ? null : _save,
                          child: _loading
                              ? SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface))
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
    return const Row(
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
            ? Theme.of(context).colorScheme.primary
            : active
                ? Theme.of(context).colorScheme.surface
                : Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
      ),
      child: Center(
        child: done
            ? Icon(Icons.check,
                size: 16, color: Theme.of(context).colorScheme.onSurface)
            : Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant)),
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
          color: done
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface.withValues(alpha: 0.3)));
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(PortalTokens.radiusPanel),
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
            child: Icon(Icons.person,
                size: 44,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle),
              child: Icon(Icons.camera_alt,
                  size: 14, color: Theme.of(context).colorScheme.onSurface),
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
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith());
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
                color: Theme.of(context).colorScheme.primary, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
