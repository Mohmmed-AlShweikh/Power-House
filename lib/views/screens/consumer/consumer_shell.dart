import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_tab.dart';
import 'usage_tab.dart';
import 'bills_tab.dart';
import 'alerts_tab.dart';
import 'profile_tab.dart';

class ConsumerShell extends ConsumerStatefulWidget {
  const ConsumerShell({super.key});
  @override
  ConsumerState<ConsumerShell> createState() => _ConsumerShellState();
}

class _ConsumerShellState extends ConsumerState<ConsumerShell> {
  int _index = 0;

  static const _tabs = [
    HomeTab(),
    UsageTab(),
    BillsTab(),
    AlertsTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: const Color(0xFF64748B),
            selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            elevation: 0,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined),     activeIcon: Icon(Icons.home),          label: 'الرئيسية'),
              BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart),     label: 'الاستهلاك'),
              BottomNavigationBarItem(icon: Icon(Icons.receipt_outlined),   activeIcon: Icon(Icons.receipt),       label: 'الفواتير'),
              BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), activeIcon: Icon(Icons.notifications), label: 'التنبيهات'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline),     activeIcon: Icon(Icons.person),        label: 'الملف'),
            ],
          ),
        ),
      ),
    );
  }
}
