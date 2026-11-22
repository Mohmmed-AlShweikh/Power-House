import 'package:flutter/material.dart';
class PortalPasswordField extends StatefulWidget {
 final TextEditingController controller;final String label;final bool enabled;final TextInputAction action;final ValueChanged<String>? onSubmitted;final Iterable<String>? hints;
 const PortalPasswordField({super.key,required this.controller,required this.label,this.enabled=true,this.action=TextInputAction.next,this.onSubmitted,this.hints});
 @override State<PortalPasswordField> createState()=>_PortalPasswordFieldState();
}
class _PortalPasswordFieldState extends State<PortalPasswordField>{bool hidden=true;
 @override Widget build(BuildContext context)=>TextField(controller:widget.controller,enabled:widget.enabled,obscureText:hidden,autocorrect:false,enableSuggestions:false,keyboardType:TextInputType.visiblePassword,textInputAction:widget.action,onSubmitted:widget.onSubmitted,autofillHints:widget.hints,decoration:InputDecoration(labelText:widget.label,suffixIcon:IconButton(tooltip:hidden?'إظهار كلمة المرور':'إخفاء كلمة المرور',onPressed:widget.enabled?()=>setState(()=>hidden=!hidden):null,icon:Icon(hidden?Icons.visibility_outlined:Icons.visibility_off_outlined))));
}
