import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/portal_tokens.dart';

/// Same centered 288dp no-background icon canvas as Android 12's native splash.
/// The native splash covers cold startup; this is the slow-transition fallback.
class AuthLoadingScreen extends StatefulWidget {
  const AuthLoadingScreen({super.key});
  @override
  State<AuthLoadingScreen> createState() => _AuthLoadingScreenState();
}

class _AuthLoadingScreenState extends State<AuthLoadingScreen> {
  late final Timer timer;
  bool slow = false;
  @override
  void initState() {
    super.initState();
    timer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => slow = true);
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
            statusBarColor: PortalTokens.darkCanvas,
            systemNavigationBarColor: PortalTokens.darkCanvas,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarIconBrightness: Brightness.light),
        child: Scaffold(
            backgroundColor: PortalTokens.darkCanvas,
            body: Stack(fit: StackFit.expand, children: [
              Center(
                  child: Image.asset(
                      'assets/brand/approved-a/splash-android12-dark-1152.png',
                      key: const ValueKey('continuous-splash-logo'),
                      width: 288,
                      height: 288,
                      filterQuality: FilterQuality.high,
                      semanticLabel: 'بوابة المولدات')),
              if (slow)
                Center(
                    child: Transform.translate(
                        offset: const Offset(0, 176),
                        child: const SizedBox(
                            width: 48,
                            height: 2,
                            child: LinearProgressIndicator(
                                color: PortalTokens.primaryDark,
                                backgroundColor: PortalTokens.darkBorder,
                                semanticsLabel: 'جارٍ استعادة الجلسة')))),
            ])),
      );
}
