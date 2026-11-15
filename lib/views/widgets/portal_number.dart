import 'package:flutter/material.dart';

/// Presentation-only bidi isolation. Never parses or changes numeric values.
/// Arabic remains RTL; contiguous Latin/unit/currency runs retain LTR order.
class PortalNumber extends StatelessWidget {
  final String value;
  final TextStyle? style;
  final TextAlign? textAlign;
  const PortalNumber(this.value, {super.key, this.style, this.textAlign});

  static final _latinRun =
      RegExp(r'[A-Za-z0-9₪€$%…—+\-]+(?:[\s:.,/+\-]*[A-Za-z0-9₪€$%…—+\-]+)*');
  static String isolate(String text) => text.replaceAllMapped(
        _latinRun,
        (match) => '\u2066${match[0]}\u2069',
      );

  @override
  Widget build(BuildContext context) => Semantics(
        label: value,
        child: ExcludeSemantics(
            child: Text(isolate(value),
                textDirection: TextDirection.rtl,
                textAlign: textAlign,
                style: style ?? Theme.of(context).textTheme.bodyMedium)),
      );
}
