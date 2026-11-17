import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/portal_tokens.dart';
import 'portal_keyboard.dart';

class PortalAuthPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const PortalAuthPage(
      {super.key, required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: PortalFocusReveal(
            child: LayoutBuilder(builder: (context, constraints) {
              return SingleChildScrollView(
                key: PageStorageKey('auth-$title'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: PortalTokens.pagePadding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minHeight: math.max(
                          0, constraints.maxHeight - PortalTokens.gutter * 2)),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                          maxWidth: PortalTokens.authWidth),
                      child: Column(
                        key: const ValueKey('auth-centered-group'),
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                              child: Image.asset(
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? 'assets/brand/approved-a/mark-reversed-384.png'
                                      : 'assets/brand/approved-a/mark-primary-384.png',
                                  width: PortalTokens.authLogo,
                                  height: PortalTokens.authLogo,
                                  semanticLabel: 'بوابة المولدات')),
                          const SizedBox(height: PortalTokens.lg),
                          Text(title,
                              textAlign: TextAlign.center,
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          Text('بوابة المولدات',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: PortalTokens.xl),
                          ...children,
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      );
}
