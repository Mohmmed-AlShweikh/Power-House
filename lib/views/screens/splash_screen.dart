import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../config/colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: 900.ms);
    _ctrl.forward();
    Future.delayed(3.seconds, () {
      if (mounted) context.go('/login');
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppColors.primaryDarkDM, AppColors.darkBackground]
                : [AppColors.primaryDark, AppColors.primary],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bolt, size: 56, color: Colors.white),
                )
                    .animate(controller: _ctrl)
                    .fadeIn(duration: 600.ms)
                    .scaleXY(begin: 0.75, end: 1.0, duration: 600.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 28),
                Text(
                  'بوابة المولدات',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                )
                    .animate(controller: _ctrl)
                    .fadeIn(delay: 200.ms, duration: 500.ms)
                    .slideY(begin: 0.3, end: 0, delay: 200.ms, duration: 500.ms),
                const SizedBox(height: 8),
                Text(
                  'Generator Portal',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 15,
                    letterSpacing: 1.2,
                  ),
                )
                    .animate(controller: _ctrl)
                    .fadeIn(delay: 400.ms, duration: 400.ms),
                const SizedBox(height: 60),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white.withOpacity(0.7),
                  ),
                )
                    .animate(controller: _ctrl)
                    .fadeIn(delay: 600.ms, duration: 300.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
