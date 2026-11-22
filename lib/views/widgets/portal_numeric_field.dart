import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/contact_fields.dart';
class PortalDigitFormatter extends TextInputFormatter {
 const PortalDigitFormatter();
 @override TextEditingValue formatEditUpdate(TextEditingValue oldValue,TextEditingValue newValue)=>newValue.copyWith(text:normalizeDigits(newValue.text).replaceAll('٫','.'));
}
class PortalNumericField extends StatelessWidget {
 final TextDirection? textDirection;
 final TextEditingController? controller;final InputDecoration? decoration;final TextInputType? keyboardType;final TextStyle? style;final bool readOnly,enabled,autofocus,obscureText;final int? maxLength,maxLines;final ValueChanged<String>? onChanged,onSubmitted;final TextInputAction? textInputAction;
 const PortalNumericField({super.key,this.controller,this.textDirection,this.decoration,this.keyboardType,this.style,this.readOnly=false,this.enabled=true,this.autofocus=false,this.obscureText=false,this.maxLength,this.maxLines=1,this.onChanged,this.onSubmitted,this.textInputAction});
 @override Widget build(BuildContext context){final numeric=keyboardType?.index==TextInputType.number.index||keyboardType==TextInputType.phone;return TextField(controller:controller,decoration:decoration,keyboardType:keyboardType,style:style,readOnly:readOnly,enabled:enabled,autofocus:autofocus,obscureText:obscureText,maxLength:maxLength,maxLines:maxLines,onChanged:onChanged,onSubmitted:onSubmitted,textInputAction:textInputAction,textDirection:numeric?TextDirection.ltr:textDirection,textAlign:numeric?TextAlign.right:TextAlign.start,inputFormatters:numeric?const [PortalDigitFormatter()]:null);}
}
