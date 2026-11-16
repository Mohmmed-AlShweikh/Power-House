import 'package:flutter/material.dart';
import 'portal_keyboard.dart';

Future<String?> requestRejectionReason(BuildContext context,
        {String title = 'سبب الرفض', String actionLabel = 'تأكيد الرفض'}) =>
    showPortalFormDialog<String>(
        context: context,
        builder: (_) => _ReasonDialog(title: title, actionLabel: actionLabel));

class _ReasonDialog extends StatefulWidget {
  final String title, actionLabel;
  const _ReasonDialog({required this.title, required this.actionLabel});
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
          title: Text(widget.title),
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
                child: Text(widget.actionLabel))
          ]);
}
