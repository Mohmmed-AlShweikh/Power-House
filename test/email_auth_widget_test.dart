import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:generator_portal/providers/auth_provider.dart';
import 'package:generator_portal/services/credential_service.dart';
import 'package:generator_portal/views/screens/credential_screen.dart';
import 'package:generator_portal/theme/portal_theme.dart';
import 'support/credential_fakes.dart';
import 'support/multi_auth_fixture.dart';
class EmailFixture extends MultiAuthFixture {
 String? email,password;
 @override Future<String?> login(String email,String password)async{this.email=email;this.password=password;return password=='wrong'?genericAuthError:null;}
}
void main(){
 Future<EmailFixture> boot(WidgetTester tester,CredentialMode mode,FakeCredentials service,Brightness brightness)async{
  tester.view.physicalSize=const Size(430,1000);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  final auth=EmailFixture();final router=GoRouter(initialLocation:'/test',routes:[GoRoute(path:'/test',builder:(_,__)=>CredentialScreen(mode:mode)),GoRoute(path:'/forgot-password',builder:(_,__)=>const CredentialScreen(mode:CredentialMode.recover)),GoRoute(path:'/register',builder:(_,__)=>const CredentialScreen(mode:CredentialMode.create)),GoRoute(path:'/login',builder:(_,__)=>const CredentialScreen(mode:CredentialMode.login))]);addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(overrides:[authProvider.overrideWith((ref)=>auth),credentialServiceProvider.overrideWithValue(service)],child:MaterialApp.router(routerConfig:router,theme:buildPortalTheme(brightness),locale:const Locale('ar'),supportedLocales:const [Locale('ar')],localizationsDelegates:const [GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,GlobalCupertinoLocalizations.delegate])));await tester.pumpAndSettle();return auth;
 }
 Future<void> field(WidgetTester t,String key,String value)async{final f=find.byKey(ValueKey(key));await t.ensureVisible(f);await t.enterText(f,value);}
 Future<void> tap(WidgetTester t,String label)async{final f=find.text(label).last;await t.ensureVisible(f);await t.tap(f);await t.pumpAndSettle();}
 for(final brightness in Brightness.values){
  testWidgets('email login and generic failure ${brightness.name}',(t)async{final auth=await boot(t,CredentialMode.login,FakeCredentials(),brightness);await field(t,'email','test@example.com');await field(t,'password','wrong');await tap(t,'تسجيل الدخول');expect(auth.email,'test@example.com');expect(find.text(genericAuthError),findsOneWidget);expect(find.text('الدخول برقم الهاتف'),findsNothing);});
  testWidgets('registration password rules and both roles ${brightness.name}',(t)async{final service=FakeCredentials();await boot(t,CredentialMode.create,service,brightness);await field(t,'email','new@example.com');await field(t,'password','weak');await field(t,'password-confirm','weak');await tap(t,'إنشاء الحساب وإرسال التحقق');expect(service.submittedEmail,isNull);await field(t,'password','Strong123');await field(t,'password-confirm','Strong123');await tap(t,'صاحب مولد');await tap(t,'إنشاء الحساب وإرسال التحقق');expect(service.submittedEmail,'new@example.com');});
  testWidgets('password reset by email does not disclose existence ${brightness.name}',(t)async{final service=FakeCredentials();await boot(t,CredentialMode.login,service,brightness);await tap(t,'نسيت كلمة المرور؟');await field(t,'email','test@example.com');await tap(t,'إرسال رابط الاستعادة');expect(service.resetEmail,'test@example.com');expect(find.textContaining('إذا كان البريد مسجلاً'),findsOneWidget);});
  testWidgets('unverified email offers reload and resend ${brightness.name}',(t)async{final service=FakeCredentials()..verified=false;await boot(t,CredentialMode.verify,service,brightness);await tap(t,'تحققت من البريد');expect(find.textContaining('لم يتم التحقق بعد'),findsOneWidget);await tap(t,'إعادة إرسال رسالة التحقق');expect(service.verificationSent,true);});
 }
}
