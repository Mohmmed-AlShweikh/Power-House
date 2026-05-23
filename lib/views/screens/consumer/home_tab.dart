import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../config/colors.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).profile;
    final theme = Theme.of(context);
    final genAsync = ref.watch(generatorProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with gradient
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppColors.primaryDark,
            automaticallyImplyLeading: false,
            actions: [
              Consumer(
                builder: (_, ref, __) {
                  final themeMode = ref.watch(themeProvider);
                  return IconButton(
                    icon: Icon(
                      themeMode == ThemeMode.dark
                          ? Icons.light_mode
                          : Icons.dark_mode,
                      color: Colors.white,
                    ),
                    onPressed: () => ref.read(themeProvider.notifier).toggle(),
                  );
                },
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
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('مرحباً، ${profile?.name ?? 'زائر'}! 👋',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        Text(profile?.address ?? '',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 13)),
                      ],
                    ),
                    const Spacer(),
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined,
                              color: Colors.white),
                          onPressed: () {},
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                                color: AppColors.error, shape: BoxShape.circle),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Generator status card
                genAsync.when(
                  data: (gen) => _GeneratorStatusCard(isOn: gen.isOn),
                  loading: () => const _GeneratorStatusCard(isOn: true),
                  error: (_, __) => const _GeneratorStatusCard(isOn: false),
                ),
                const SizedBox(height: 16),

                Text('الاستهلاك الشهري', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatCard(
                        label: 'هذا الشهر',
                        value: '142 kWh',
                        icon: Icons.flash_on,
                        color: AppColors.primary),
                    const SizedBox(width: 12),
                    _StatCard(
                        label: 'الفاتورة',
                        value: '₪ 284',
                        icon: Icons.receipt_long,
                        color: AppColors.warning),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatCard(
                        label: 'الساعات',
                        value: '8 ساعة',
                        icon: Icons.timer_outlined,
                        color: AppColors.success),
                    const SizedBox(width: 12),
                    _StatCard(
                        label: 'المشتركون',
                        value: '24',
                        icon: Icons.people_outline,
                        color: const Color(0xFF8B5CF6)),
                  ],
                ),
                const SizedBox(height: 20),

                Text('آخر التنبيهات', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                _AlertItem(
                    icon: Icons.power,
                    color: AppColors.success,
                    title: 'تشغيل المولد',
                    subtitle: 'تم تشغيل المولد',
                    time: 'منذ ساعتين'),
                const SizedBox(height: 8),
                _AlertItem(
                    icon: Icons.warning_amber,
                    color: AppColors.warning,
                    title: 'انتهاء وقود قريباً',
                    subtitle: 'متبقي 20% من الوقود',
                    time: 'منذ 5 ساعات'),
                const SizedBox(height: 8),
                _AlertItem(
                    icon: Icons.receipt,
                    color: AppColors.primary,
                    title: 'فاتورة جديدة',
                    subtitle: 'فاتورة يوليو ₪284',
                    time: 'أمس'),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneratorStatusCard extends StatelessWidget {
  final bool isOn;
  const _GeneratorStatusCard({required this.isOn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOn
              ? [const Color(0xFF16A34A), const Color(0xFF22C55E)]
              : [const Color(0xFF64748B), const Color(0xFF94A3B8)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isOn ? AppColors.success : AppColors.lightMuted)
                .withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.bolt, color: Colors.white, size: 32),
          ).animate().fadeIn().scaleXY(
              begin: 0.8, end: 1, duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isOn ? 'المولد يعمل الآن' : 'المولد متوقف',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(isOn ? 'يعمل منذ 3 ساعات' : 'اضغط لتشغيل المولد',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.circle, size: 8, color: Colors.white),
                const SizedBox(width: 5),
                Text(isOn ? 'نشط' : 'موقف',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.lightMuted)),
          ],
        ),
      ).animate().fadeIn().slideY(begin: 0.2, end: 0, duration: 300.ms),
    );
  }
}

class _AlertItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle, time;
  const _AlertItem(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle,
      required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lightText)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.lightMuted)),
              ],
            ),
          ),
          Text(time,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.lightMuted)),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.1, end: 0, duration: 300.ms);
  }
}
