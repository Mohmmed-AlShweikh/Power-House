import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../views/widgets/portal_keyboard.dart';
import '../billing_shared/widgets.dart';
import '../metering/providers.dart';

Future<UserProfile?> chooseConsumer(BuildContext context) =>
    showPortalFormDialog<UserProfile>(
        context: context,
        builder: (_) => Consumer(
            builder: (context, ref, _) => AlertDialog(
                    scrollable: true,
                    title: const Text('اختر حساب المشترك المعتمد'),
                    content: FeatureData(
                        value: ref.watch(subscribersProvider),
                        retry: () => ref.invalidate(subscribersProvider),
                        builder: (rows) =>
                            Column(mainAxisSize: MainAxisSize.min, children: [
                              for (final u in rows.where((u) =>
                                  u.role == UserRole.consumer &&
                                  u.approvalStatus == ApprovalStatus.approved))
                                ListTile(
                                    title: Text(u.name),
                                    subtitle: Text(u.phone),
                                    onTap: () => Navigator.pop(context, u))
                            ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('إلغاء'))
                    ])));
Future<String?> chooseReader(BuildContext context) =>
    showPortalFormDialog<String>(
        context: context,
        builder: (_) => Consumer(
            builder: (context, ref, _) => AlertDialog(
                    scrollable: true,
                    title: const Text('إسناد القراءة'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      ListTile(
                          title: const Text('صاحب المولد'),
                          onTap: () => Navigator.pop(
                              context, ref.read(authProvider).user!.uid)),
                      FeatureData(
                          value: ref.watch(meterStaffProvider),
                          retry: () => ref.invalidate(meterStaffProvider),
                          builder: (s) =>
                              Column(mainAxisSize: MainAxisSize.min, children: [
                                for (final d in s.docs
                                    .where((d) => d.data()['active'] == true))
                                  ListTile(
                                      title: Text(d.data()['name']),
                                      onTap: () => Navigator.pop(context, d.id))
                              ]))
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('إلغاء'))
                    ])));
