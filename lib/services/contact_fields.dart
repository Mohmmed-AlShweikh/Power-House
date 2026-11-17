String normalizeDigits(String input) =>
    input.replaceAllMapped(RegExp('[٠-٩۰-۹]'), (m) {
      final c = m[0]!.codeUnitAt(0);
      return (c >= 0x6f0 ? c - 0x6f0 : c - 0x660).toString();
    });
String normalizeMobile(String input) {
  var s = normalizeDigits(input).trim().replaceAll(RegExp(r'[\s()\-]'), '');
  if (s.startsWith('00')) s = '+${s.substring(2)}';
  if (s.startsWith('+970') || s.startsWith('+972')) s = '0${s.substring(4)}';
  return s;
}

bool palestinianMobile(String input) =>
    RegExp(r'^05[69][0-9]{7}$').hasMatch(normalizeMobile(input));
String? contactError(String phone, String id, {bool requiredPhone = false}) {
  if ((requiredPhone && phone.trim().isEmpty) ||
      (phone.trim().isNotEmpty && !palestinianMobile(phone))) {
    return 'أدخل رقم جوال فلسطيني صحيحاً يبدأ بـ 059 أو 056 (أو +970 / +972)';
  }
  if (id.trim().isNotEmpty &&
      !RegExp(r'^[0-9]{9,10}$').hasMatch(normalizeDigits(id).trim())) {
    return 'الهوية اختيارية؛ أدخل 9 أو 10 أرقام';
  }
  return null;
}
