import '../../../services/firestore_reads.dart';
import '../../../providers/tenant_provider.dart';
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
    unawaited(_alertsSub?.cancel());
    _alertsSub = null;
    final auth = ref.read(authProvider);
    final uid = auth.profile?.uid ?? '';
    if (uid.isEmpty || auth.user == null || !auth.startupResolved) return;

    _alertsSub = retryFirestore(() => ref
        .read(firestoreProvider)
        .collection('alerts')
        .where('userId', isEqualTo: uid)
        .where('generatorId',
            isEqualTo: ref.read(authProvider).profile?.generatorId ?? 'default')
        .snapshots()).listen((snapshot) {
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
    }, onError: (Object error, StackTrace stack) {});
  }

  @override
  void dispose() {
    _alertsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (_, __) => _startListening());
    final tabs = [
      const HomeTab(),
      const UsageTab(),
      const BillsTab(),
      const ProfileTab(),
    ];
    return Scaffold(
        body: Stack(children: [
      Theme(
          data: buildPortalTheme(Theme.of(context).brightness),
          child: IndexedStack(index: _index, children: tabs)),
      PositionedDirectional(
          start: 0,
          end: 0,
          bottom: MediaQuery.paddingOf(context).bottom,
          child: Theme(
              data: buildPortalTheme(Theme.of(context).brightness),
              child: PortalConsumerNavigation(
                  selected: _index,
                  onSelected: (i) => setState(() => _index = i)))),
    ]));
  }
}
