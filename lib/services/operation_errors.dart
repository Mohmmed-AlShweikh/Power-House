import 'package:cloud_firestore/cloud_firestore.dart';

String operationMessage(Object e) {
  if (e is StateError) return e.message.toString();
  if (e is FormatException) return e.message;
  if (e is FirebaseException) {
    return switch (e.code) {
      'permission-denied' =>
        'لا تملك صلاحية هذه العملية. تحقق من اعتماد الحساب ونشر القواعد الصحيحة.',
      'unavailable' ||
      'deadline-exceeded' =>
        'تعذر الاتصال؛ تحقق من الإنترنت ثم أعد المحاولة.',
      'failed-precondition' => (e.message ?? '').toLowerCase().contains('index')
          ? 'يلزم نشر فهرس الاستعلام وانتظار تفعيله.'
          : 'تعارض في حالة البيانات؛ أعد تحميل الشاشة.',
      'not-found' => 'أحد السجلات المطلوبة غير موجود؛ أعد تحميل الجولة.',
      _ => 'تعذرت العملية؛ راجع التفاصيل التقنية أو أعد المحاولة.'
    };
  }
  return 'تعذر الحفظ؛ حاول مجدداً.';
}
