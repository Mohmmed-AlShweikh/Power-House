import 'package:flutter/material.dart';

/// Approved identity. Presentation values live here, never in providers.
abstract final class PortalTokens {
  static const ink = Color(0xFF173E43);
  static const primary = Color(0xFF14756B);
  static const primaryDark = Color(0xFF8AD8C7);
  static const onPrimaryDark = Color(0xFF113C35);
  static const canvas = Color(0xFFF3F1EB);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF233D42);
  static const muted = Color(0xFF53696D);
  static const border = Color(0xFFCCD8D4);
  static const darkCanvas = Color(0xFF13262A);
  static const darkSurface = Color(0xFF1B3337);
  static const darkText = Color(0xFFECF3EF);
  static const darkMuted = Color(0xFFB3C5C3);
  static const darkBorder = Color(0xFF708B89);
  static const success = Color(0xFF246B4C);
  static const successFill = Color(0xFFE9F3ED);
  static const darkSuccess = Color(0xFFA0D9B8);
  static const darkSuccessFill = Color(0xFF234338);
  static const warning = Color(0xFF8C581B);
  static const warningFill = Color(0xFFFFF2DC);
  static const darkWarning = Color(0xFFF1CC8A);
  static const darkWarningFill = Color(0xFF493B26);
  static const danger = Color(0xFFAA3F36);
  static const dangerFill = Color(0xFFFBEDEA);
  static const darkDanger = Color(0xFFFFB8AD);
  static const darkDangerFill = Color(0xFF4C302F);
  // Working is blue, not the teal brand family or the green success family.
  static const working = Color(0xFF2459A6);
  static const workingFill = Color(0xFFEAF1FC);
  static const darkWorking = Color(0xFFB0C9FF);
  static const darkWorkingFill = Color(0xFF233653);
  static const stoppedFill = Color(0xFFEDF1EF);
  static const darkStoppedFill = Color(0xFF263D40);
  static const chartSecondary = Color(0xFF598D85);
  static const darkChartSecondary = Color(0xFF6EAEA3);
  static const transparent = Colors.transparent;

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const gutter = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const target = 48.0;
  static const control = 56.0;
  static const radiusSmall = 8.0;
  static const radius = 12.0;
  static const radiusPanel = 16.0;
  static const radiusSheet = 24.0;
  static const line = 1.0;
  static const focusLine = 2.0;
  static const icon = 24.0;
  static const chartHeight = 180.0;
  static const chartBarWidth = 24.0;
  static const chartLabelHeight = 28.0;
  static const chartAxisWidth = 40.0;
  static const navHeight = 80.0;
  static const navInset = 16.0;
  static const navTile = 36.0;
  static const navLift = 12.0;
  static const navClearance = navHeight + gutter;
  static const heroHeight = 232.0;
  static const smallIconBox = 36.0;
  static const subtleShadow = Color(0x12000000);
  static const navLabel =
      TextStyle(fontSize: 12, height: 1.2, fontWeight: FontWeight.w500);
  static const navActiveLabel =
      TextStyle(fontSize: 12, height: 1.2, fontWeight: FontWeight.w700);
  static const zero = 0.0;
  static const motion = Duration(milliseconds: 160);
  static const font = 'PortalArabic';
  static const fallback = ['PortalCurrency'];
  static const pagePadding = EdgeInsets.all(gutter);
  static const panelPadding = EdgeInsets.all(lg);
  static final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radiusPanel),
  );

  static const type = TextTheme(
    displaySmall:
        TextStyle(fontSize: 32, fontWeight: FontWeight.w600, height: 1.5),
    headlineLarge:
        TextStyle(fontSize: 28, fontWeight: FontWeight.w600, height: 1.5),
    headlineMedium:
        TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.5),
    titleLarge:
        TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.5),
    titleMedium:
        TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5),
    titleSmall:
        TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.5),
    bodyLarge: TextStyle(fontSize: 16, height: 1.65),
    bodyMedium: TextStyle(fontSize: 14, height: 1.6),
    bodySmall: TextStyle(fontSize: 12, height: 1.6),
    labelLarge:
        TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.5),
    labelMedium:
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.6),
    labelSmall: TextStyle(fontSize: 12, height: 1.6),
  );
}

enum PortalTone { working, stopped, success, warning, danger }

extension PortalToneStyle on PortalTone {
  (Color, Color) colors(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (this) {
      PortalTone.working => dark
          ? (PortalTokens.darkWorking, PortalTokens.darkWorkingFill)
          : (PortalTokens.working, PortalTokens.workingFill),
      PortalTone.stopped => dark
          ? (PortalTokens.darkMuted, PortalTokens.darkStoppedFill)
          : (PortalTokens.muted, PortalTokens.stoppedFill),
      PortalTone.success => dark
          ? (PortalTokens.darkSuccess, PortalTokens.darkSuccessFill)
          : (PortalTokens.success, PortalTokens.successFill),
      PortalTone.warning => dark
          ? (PortalTokens.darkWarning, PortalTokens.darkWarningFill)
          : (PortalTokens.warning, PortalTokens.warningFill),
      PortalTone.danger => dark
          ? (PortalTokens.darkDanger, PortalTokens.darkDangerFill)
          : (PortalTokens.danger, PortalTokens.dangerFill),
    };
  }
}
