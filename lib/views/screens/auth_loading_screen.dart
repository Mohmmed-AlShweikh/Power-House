import 'package:flutter/material.dart';
import '../../theme/portal_tokens.dart';

/// In-app continuation of the native splash while restoring authentication.
class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? PortalTokens.darkCanvas : PortalTokens.canvas,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                dark
                    ? 'assets/brand/approved-a/mark-reversed-384.png'
                    : 'assets/brand/approved-a/mark-primary-384.png',
                width: PortalTokens.target * 2,
                height: PortalTokens.target * 2,
                semanticLabel: 'بوابة المولدات',
              ),
              const SizedBox(height: PortalTokens.xxl),
              const CircularProgressIndicator(
                semanticsLabel: 'جارٍ استعادة الجلسة',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
