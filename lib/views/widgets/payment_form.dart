import 'portal_keyboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bill_model.dart';
import '../../models/payment_model.dart';
import '../../services/firebase_service.dart';
import '../../theme/portal_tokens.dart';
import 'portal_components.dart';

class PaymentForm extends ConsumerStatefulWidget {
  final Bill bill;
  const PaymentForm({super.key, required this.bill});
  @override
  ConsumerState<PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends ConsumerState<PaymentForm> {
  late final amount =
      TextEditingController(text: widget.bill.amount.toString());
  final reference = TextEditingController();
  DateTime date = DateUtils.dateOnly(DateTime.now());
  String method = 'cash';
  String? error;
  bool busy = false;
  @override
  void dispose() {
    amount.dispose();
    reference.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final minor = parsePaymentMinor(amount.text);
    if (minor == null ||
        minor != widget.bill.amount * 100 ||
        reference.text.trim().isEmpty) {
      setState(() => error = 'أدخل المبلغ الكامل للفاتورة ورقم الدفع المرجعي');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(firebaseServiceProvider).submitPayment(
          widget.bill.id,
          PaymentRecord(
              amountMinor: minor,
              date: DateTime.utc(date.year, date.month, date.day)
                  .millisecondsSinceEpoch,
              reference: reference.text.trim(),
              method: method));
      if (mounted) completePortalSave(context,result:true,message:'تم حفظ العملية');
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'تعذّر إرسال السجل. تحقق من الاتصال وحالة الفاتورة ثم حاول مجدداً.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                  child: Text('تسجيل دفعة',
                      style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                  tooltip: 'إغلاق',
                  onPressed: busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close))
            ]),
            const Text(
                'أدخل بيانات الدفع للمراجعة. تسجيل الدفعة لا يعني اعتمادها أو تحصيلها إلكترونياً.'),
            const SizedBox(height: PortalTokens.lg),
            TextField(
                key: const ValueKey('payment-amount'),
                controller: amount,
                enabled: !busy,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'المبلغ المدفوع (₪)')),
            const SizedBox(height: PortalTokens.lg),
            OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final selected = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now());
                        if (selected != null && mounted) {
                          setState(() => date = selected);
                        }
                      },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                    'تاريخ الدفع: ${date.year}/${date.month}/${date.day}')),
            const SizedBox(height: PortalTokens.lg),
            DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                items: [
                  for (final entry in paymentMethods.entries)
                    DropdownMenuItem(value: entry.key, child: Text(entry.value))
                ],
                onChanged:
                    busy ? null : (value) => setState(() => method = value!)),
            const SizedBox(height: PortalTokens.lg),
            TextField(
                key: const ValueKey('payment-reference'),
                controller: reference,
                enabled: !busy,
                maxLength: 80,
                decoration:
                    const InputDecoration(labelText: 'رقم المرجع / سند القبض')),
            if (error != null) PortalErrorState(error!),
            PortalActionButton(
                label: 'إرسال للمراجعة', busy: busy, onPressed: submit),
          ]);
}
