import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/data_provider.dart';
import '../../../config/colors.dart';

class UsageTab extends ConsumerWidget {
  const UsageTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(usageProvider);
    final theme = Theme.of(context);
    final maxKwh = data.map((d) => d.kwh).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.primaryDark,
            automaticallyImplyLeading: false,
            title: Text('الاستهلاك', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
          
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    _SummaryCard(label: 'متوسط شهري', value: '132 kWh', icon: Icons.trending_up, color: AppColors.primary),
                    const SizedBox(width: 12),
                    _SummaryCard(label: 'هذا الشهر', value: '142 kWh', icon: Icons.flash_on, color: AppColors.success),
                  ],
                ),
                const SizedBox(height: 16),
                _ChartCard(data: data, maxKwh: maxKwh),
                const SizedBox(height: 16),
                _MonthlyTable(data: data),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _SummaryCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.lightMuted)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2, end: 0, duration: 300.ms),
  );
}

class _ChartCard extends StatelessWidget {
  final List<UsageMonth> data;
  final double maxKwh;
  const _ChartCard({required this.data, required this.maxKwh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الاستهلاك الشهري (kWh)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((d) {
                final isLast = d == data.last;
                final h = (d.kwh / maxKwh) * 130;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isLast)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                            child: Text('${d.kwh.toInt()}',
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                          ),
                        Container(
                          height: h,
                          decoration: BoxDecoration(
                            color: isLast ? AppColors.primary : AppColors.primary.withOpacity(0.25),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(d.month, style: const TextStyle(fontSize: 9, color: AppColors.lightMuted)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}

class _MonthlyTable extends StatelessWidget {
  final List<UsageMonth> data;
  const _MonthlyTable({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Row(
              children: [
                Expanded(child: Text('الشهر', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.lightMuted))),
                Expanded(child: Text('الاستهلاك', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.lightMuted))),
                Expanded(child: Text('التكلفة', textAlign: TextAlign.end, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.lightMuted))),
              ],
            ),
          ),
          ...data.reversed.take(5).map((d) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.lightBorder.withOpacity(0.5))),
            ),
            child: Row(
              children: [
                Expanded(child: Text(d.month, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                Expanded(child: Text('${d.kwh.toInt()} kWh', textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600))),
                Expanded(child: Text('₪${d.cost}', textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              ],
            ),
          )),
        ],
      ),
    ).animate().fadeIn();
  }
}
