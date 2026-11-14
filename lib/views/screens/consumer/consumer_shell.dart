import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../theme/portal_theme.dart';
import '../../widgets/portal_components.dart';
import '../../../services/local_notification_service.dart';
import 'home_tab.dart';
import 'usage_tab.dart';
import 'bills_tab.dart';
import 'profile_tab.dart';

class ConsumerShell extends ConsumerStatefulWidget {
  const ConsumerShell({super.key});
  @override
  ConsumerState<ConsumerShell> createState() => _ConsumerShellState();
}

class _ConsumerShellState extends ConsumerState<ConsumerShell> {
  int _index = 0;
  StreamSubscription<QuerySnapshot>? _alertsSub;
  final DateTime _startTime = DateTime.now();
  final Set<String> _seenAlertIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startListening());
  }

  void _startListening() {
    final uid = ref.read(authProvider).profile?.uid ?? '';
    if (uid.isEmpty) return;

    _alertsSub = FirebaseFirestore.instance
        .collection('alerts')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final docId = change.doc.id;
        if (_seenAlertIds.contains(docId)) continue;
        _seenAlertIds.add(docId);

        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final createdAt = DateTime.fromMillisecondsSinceEpoch(
          (data['createdAt'] as int?) ?? 0,
        );
        if (createdAt.isBefore(_startTime)) continue;

        final title = (data['title'] as String?) ?? 'تنبيه';
        final body = (data['body'] as String?) ?? '';
        LocalNotificationService().show(title, body);
      }
    });
  }

  @override
  void dispose() {
    _alertsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const HomeTab(),
      const UsageTab(),
      const BillsTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: Theme(
        data: buildPortalTheme(Theme.of(context).brightness),
        child: PortalConsumerNavigation(
            selected: _index, onSelected: (i) => setState(() => _index = i)),
      ),
    );
  }
}
