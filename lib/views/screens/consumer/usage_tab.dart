import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/bill_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_provider.dart';
import '../../../config/colors.dart';

class UsageTab extends ConsumerWidget {
  const UsageTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).profile;
    final uid = profile?.uid ?? '';
    final billsAsync = ref.watch(billsProvider(uid));
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            title: Text('الاستهلاك',
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: Colors.white)),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                billsAsync.when(
                  data: (bills) {
                    if (bills.isEmpty) return const _EmptyUsage();
                    return _UsageContent(bills: bills);
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => const _EmptyUsage(),
                ),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageContent extends StatelessWidget {
  final List<Bill> bills;
  const _UsageContent({required this.bills});

  @override
  Widget build(BuildContext context) {
    final currentMonth = currentMonthArabic();
    final currentYear = DateTime.now().year;

    final currentBill = bills
        .where((b) => b.month == currentMonth && b.year == currentYear)
        .toList();
    final currentKwh = currentBill.isNotEmpty ? currentBill.first.kwh : 0.0;

    final allKwh = bills.map((b) => b.kwh).toList();
    final avgKwh = allKwh.isEmpty
        ? 0.0
        : allKwh.reduce((a, b) => a + b) / allKwh.length;

    final chartData = bills.take(7).toList().reversed.toList();
    final maxKwh = chartData.isEmpty
        ? 1.0
        : chartData.map((b) => b.kwh).reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        Row(
          children: [
            _SummaryCard(
                label: 'متوسط شهري',
                value: '${avgKwh.toStringAsFixed(0)} kWh',
                icon: Icons.trending_up,
                color: AppColors.primary),
            const SizedBox(width: 12),
            _SummaryCard(
                label: 'هذا الشهر',
                value: currentKwh > 0
                    ? '${currentKwh.toStringAsFixed(0)} kWh'
                    : '— kWh',
                icon: Icons.flash_on,
                color: AppColors.success),
          ],
        ),
        const SizedBox(height: 16),
        if (chartData.isNotEmpty)
          _ChartCard(bills: chartData, maxKwh: maxKwh),
        const SizedBox(height: 16),
        _MonthlyTable(bills: bills),
      ],
    );
  }
}

class _EmptyUsage extends StatelessWidget {
  const _EmptyUsage();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 52, color: AppColors.lightMuted),
          SizedBox(height: 12),
          Text('لا توجد بيانات استهلاك بعد',
              style: TextStyle(color: AppColors.lightMuted, fontSize: 15)),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _SummaryCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: color),
                        overflow: TextOverflow.ellipsis),
                    Text(label,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.lightMuted)),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn().slideY(begin: 0.2, end: 0, duration: 300.ms),
      );
}

class _ChartCard extends StatelessWidget {
  final List<Bill> bills;
  final double maxKwh;
  const _ChartCard({required this.bills, required this.maxKwh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
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
              children: bills.map((b) {
                final isLast = b == bills.last;
                final h = maxKwh > 0 ? (b.kwh / maxKwh) * 130 : 0.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isLast)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(6)),
                            child: Text('${b.kwh.toInt()}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700)),
                          ),
                        Container(
                          height: h,
                          decoration: BoxDecoration(
                            color: isLast
                                ? AppColors.primary
                                : AppColors.primary.withOpacity(0.25),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(b.month,
                            style: const TextStyle(
                                fontSize: 9, color: AppColors.lightMuted)),
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
  final List<Bill> bills;
  const _MonthlyTable({required this.bills});

  @override
  Widget build(BuildContext context) {
    final display = bills.take(6).toList();
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Row(
              children: [
                Expanded(
                    child: Text('الشهر',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lightMuted))),
                Expanded(
                    child: Text('الاستهلاك',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lightMuted))),
                Expanded(
                    child: Text('التكلفة',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lightMuted))),
              ],
            ),
          ),
          ...display.map((b) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(
                          color: AppColors.lightBorder.withOpacity(0.5))),
                ),
                child: Row(
                  children: [
                    Expanded(
                        child: Text('${b.month} ${b.year}',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500))),
                    Expanded(
                        child: Text('${b.kwh.toStringAsFixed(0)} kWh',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600))),
                    Expanded(
                        child: Text('₪${b.amount}',
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600))),
                  ],
                ),
              )),
        ],
      ),
    ).animate().fadeIn();
  }
}
