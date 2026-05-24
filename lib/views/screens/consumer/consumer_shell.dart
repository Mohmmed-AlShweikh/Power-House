import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_provider.dart';
import '../../../services/firebase_service.dart';
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

  void _goToAlerts() => _onTap(3);

  Future<void> _onTap(int i) async {
    setState(() => _index = i);
    if (i == 3) {
      final uid = ref.read(authProvider).profile?.uid ?? '';
      if (uid.isNotEmpty) {
        await FirebaseService().markAllAlertsRead(uid);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authProvider).profile?.uid ?? '';
    final alertsAsync = ref.watch(alertsProvider(uid));
    final unreadCount = alertsAsync.when(
      data: (alerts) => alerts.where((a) => !a.read).length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    final tabs = [
      HomeTab(onNotificationTap: _goToAlerts),
      const UsageTab(),
      const BillsTab(),
      const AlertsTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
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
            onTap: _onTap,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: const Color(0xFF64748B),
            selectedLabelStyle:
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            elevation: 0,
            items: [
              const BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'الرئيسية'),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart_outlined),
                  activeIcon: Icon(Icons.bar_chart),
                  label: 'الاستهلاك'),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_outlined),
                  activeIcon: Icon(Icons.receipt),
                  label: 'الفواتير'),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: unreadCount > 0 && _index != 3,
                  label: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(fontSize: 10),
                  ),
                  child: const Icon(Icons.notifications_outlined),
                ),
                activeIcon: const Icon(Icons.notifications),
                label: 'التنبيهات',
              ),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'الملف'),
            ],
          ),
        ),
      ),
    );
  }
}
