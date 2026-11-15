import 'package:flutter/material.dart';
import 'portal_keyboard.dart';

Future<String?> requestRejectionReason(BuildContext context) =>
    showPortalFormDialog<String>(
        context: context, builder: (_) => const _ReasonDialog());

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();
  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          scrollable: true,
          title: const Text('سبب رفض المولد'),
          content: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'سبب الرفض')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')),
            TextButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    Navigator.pop(context, controller.text.trim());
                  }
                },
                child: const Text('تأكيد الرفض'))
          ]);
}
