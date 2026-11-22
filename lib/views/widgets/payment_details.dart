import 'package:flutter/material.dart';
import '../../models/payment_model.dart';
import 'portal_components.dart';

class PaymentDetails extends StatelessWidget {
  final PaymentRecord payment;
  const PaymentDetails({super.key, required this.payment});
  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(payment.date, isUtc: true);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PortalLabelValue(
          label: 'المبلغ المسجّل', value: '₪${payment.amountText}'),
      PortalLabelValue(
          label: 'تاريخ الدفع',
          value:
              '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}'),
      PortalLabelValue(label: 'الرقم المرجعي', value: payment.reference),
      PortalLabelValue(label: 'طريقة الدفع', value: payment.methodText),
    ]);
  }
}
