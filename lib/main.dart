import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/router.dart';
import 'providers/theme_provider.dart';
import 'theme/portal_theme.dart';
import 'theme/portal_tokens.dart';
import 'views/widgets/portal_components.dart';
import 'services/firebase_service.dart';
import 'services/local_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  await LocalNotificationService().init();
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return PortalExceptionView(details.exception.toString());
  };
  runApp(const ProviderScope(child: GeneratorPortalApp()));
}

class GeneratorPortalApp extends ConsumerWidget {
  const GeneratorPortalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'بوابة المولدات',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: themeMode,
      theme: buildPortalTheme(Brightness.light),
      darkTheme: buildPortalTheme(Brightness.dark),
      themeAnimationDuration: PortalTokens.motion,
      themeAnimationCurve: Curves.easeInOut,
      routerConfig: router,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
    );
  }
}
