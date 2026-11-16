import 'package:flutter/widgets.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NativeSplashController {
  static final shared = NativeSplashController();
  final VoidCallback _remove;
  bool _preserved = false;
  bool get preserved => _preserved;
  NativeSplashController() : _remove = FlutterNativeSplash.remove;
  NativeSplashController.testing(VoidCallback remove)
      : _remove = remove,
        _preserved = true;
  void preserve(WidgetsBinding binding) {
    FlutterNativeSplash.preserve(widgetsBinding: binding);
    _preserved = true;
  }

  void release() {
    if (!_preserved) return;
    _preserved = false;
    _remove();
  }
}

final nativeSplashProvider =
    Provider<NativeSplashController>((ref) => NativeSplashController.shared);

/// Release after the destination frame, not after an arbitrary startup delay.
class NativeSplashRelease extends StatefulWidget {
  final GoRouter router;
  final NativeSplashController controller;
  final bool ready;
  final Widget child;
  const NativeSplashRelease(
      {super.key,
      required this.router,
      required this.controller,
      required this.ready,
      required this.child});
  @override
  State<NativeSplashRelease> createState() => _NativeSplashReleaseState();
}

class _NativeSplashReleaseState extends State<NativeSplashRelease> {
  bool scheduled = false;
  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(check);
    check();
  }

  @override
  void didUpdateWidget(covariant NativeSplashRelease oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router.routerDelegate.removeListener(check);
      widget.router.routerDelegate.addListener(check);
    }
    check();
  }

  void check() {
    if (scheduled || !widget.controller.preserved) return;
    scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduled = false;
      if (!mounted || !widget.ready) return;
      final path = widget.router.routerDelegate.currentConfiguration.uri.path;
      if (path.isNotEmpty && path != '/splash') widget.controller.release();
    });
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
