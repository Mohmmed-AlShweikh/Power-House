import 'package:flutter/material.dart';
import 'portal_tokens.dart';

ThemeData buildPortalTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: PortalTokens.primary,
    brightness: brightness,
  ).copyWith(
    primary: dark ? PortalTokens.primaryDark : PortalTokens.primary,
    primaryContainer:
        dark ? PortalTokens.darkStoppedFill : PortalTokens.stoppedFill,
    onPrimaryContainer: dark ? PortalTokens.primaryDark : PortalTokens.primary,
    surfaceContainerHighest:
        dark ? PortalTokens.darkStoppedFill : PortalTokens.stoppedFill,
    onPrimary: dark ? PortalTokens.onPrimaryDark : PortalTokens.surface,
    secondary: dark ? PortalTokens.darkWorking : PortalTokens.working,
    surface: dark ? PortalTokens.darkSurface : PortalTokens.surface,
    onSurface: dark ? PortalTokens.darkText : PortalTokens.text,
    onSurfaceVariant: dark ? PortalTokens.darkMuted : PortalTokens.muted,
    outline: dark ? PortalTokens.darkBorder : PortalTokens.muted,
    outlineVariant: dark ? PortalTokens.darkBorder : PortalTokens.border,
    error: dark ? PortalTokens.darkDanger : PortalTokens.danger,
    errorContainer:
        dark ? PortalTokens.darkDangerFill : PortalTokens.dangerFill,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: PortalTokens.font,
    fontFamilyFallback: PortalTokens.fallback,
  );
  final text = PortalTokens.type.apply(
    fontFamily: PortalTokens.font,
    fontFamilyFallback: PortalTokens.fallback,
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  final outline = OutlineInputBorder(
    borderRadius: BorderRadius.circular(PortalTokens.radius),
    borderSide: BorderSide(color: scheme.outline),
  );
  final button = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(
        Size(PortalTokens.target, PortalTokens.control)),
    padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: PortalTokens.lg)),
    textStyle: WidgetStatePropertyAll(text.labelLarge),
    shape: WidgetStatePropertyAll(RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(PortalTokens.radius),
    )),
    elevation: const WidgetStatePropertyAll(PortalTokens.zero),
    tapTargetSize: MaterialTapTargetSize.padded,
    animationDuration: PortalTokens.motion,
  );
  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor:
        dark ? PortalTokens.darkCanvas : PortalTokens.canvas,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: PortalTokens.zero,
      margin: EdgeInsets.zero,
      shape: PortalTokens.shape
          .copyWith(side: BorderSide(color: scheme.outlineVariant)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: PortalTokens.transparent,
      elevation: PortalTokens.zero,
      scrolledUnderElevation: PortalTokens.zero,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
        style: button.copyWith(
      backgroundColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.disabled)
              ? scheme.surfaceContainerHighest
              : scheme.primary),
      foregroundColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.disabled)
              ? scheme.onSurfaceVariant
              : scheme.onPrimary),
    )),
    filledButtonTheme: FilledButtonThemeData(style: button),
    outlinedButtonTheme: OutlinedButtonThemeData(style: button),
    textButtonTheme: TextButtonThemeData(style: button),
    iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size.square(PortalTokens.target)),
      iconSize: WidgetStatePropertyAll(PortalTokens.icon),
    )),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      contentPadding: PortalTokens.panelPadding,
      border: outline,
      enabledBorder: outline,
      focusedBorder: outline.copyWith(
          borderSide: BorderSide(
        color: scheme.primary,
        width: PortalTokens.focusLine,
      )),
      labelStyle: text.bodyMedium,
      hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
    ),
    dividerTheme: DividerThemeData(
        color: scheme.outlineVariant, thickness: PortalTokens.line),
    dialogTheme: DialogThemeData(
        shape: PortalTokens.shape, backgroundColor: scheme.surface),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
        top: Radius.circular(PortalTokens.radiusSheet),
      )),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      indicatorColor:
          dark ? PortalTokens.darkStoppedFill : PortalTokens.stoppedFill,
    ),
    chipTheme: base.chipTheme
        .copyWith(labelStyle: text.labelMedium, shape: PortalTokens.shape),
    snackBarTheme: SnackBarThemeData(
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onPrimary)),
  );
}
