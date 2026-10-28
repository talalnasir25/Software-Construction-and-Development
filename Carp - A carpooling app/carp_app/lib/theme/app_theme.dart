// ALL colors and theme settings for Carp live in this file.
// Screens never use hard-coded colors: they read Theme.of(context).colorScheme
// or context.palette (the extra Carp colors below).

import 'package:flutter/material.dart';

/// One place for spacing so every screen looks consistent.
class Gap {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 16.0;
  static const l = 24.0;
  static const xl = 32.0;
  static const radius = 16.0;
}

/// Raw brand colors. Only used inside this file.
class _Light {
  static const primary = Color(0xFF2563EB); // electric blue
  static const secondary = Color(0xFFFF8A00); // sunny orange
  static const success = Color(0xFF10B981); // fresh green
  static const warning = Color(0xFFF59E0B); // amber
  static const error = Color(0xFFEF4444); // red
  static const background = Color(0xFFF8FAFC);
  static const card = Color(0xFFFFFFFF);
  static const text = Color(0xFF0F172A);
  static const textMuted = Color(0xFF475569);
  static const outline = Color(0xFF94A3B8);
  static const outlineSoft = Color(0xFFE2E8F0);
  static const container = Color(0xFFF1F5F9);
  static const highlightSoft = Color(0xFFFFF1E0); // orange tint for info cards
  static const onHighlightSoft = Color(0xFF7C2D12);

  // Deeper shades of the same hues, used for SMALL TEXT on white
  // so it stays readable (contrast 4.5:1 or better).
  static const successText = Color(0xFF047857);
  static const warningText = Color(0xFFB45309);
  static const errorText = Color(0xFFDC2626);
  static const secondaryText = Color(0xFFC2410C);
}

/// Same colors, slightly brighter so they pop on dark backgrounds.
class _Dark {
  static const primary = Color(0xFF60A5FA);
  static const secondary = Color(0xFFFFA940);
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const error = Color(0xFFF87171);
  static const background = Color(0xFF0F172A); // deep navy
  static const card = Color(0xFF1E293B);
  static const text = Color(0xFFF1F5F9);
  static const textMuted = Color(0xFF94A3B8);
  static const outline = Color(0xFF64748B);
  static const outlineSoft = Color(0xFF334155);
  static const container = Color(0xFF273449);
  static const highlightSoft = Color(0xFF3A2A17); // orange tint for info cards
  static const onHighlightSoft = Color(0xFFFFD8A8);
  static const onBright = Color(0xFF0F172A); // dark text on bright fills
}

const _darkTextOnOrange = Color(0xFF1C1917);
const _white = Color(0xFFFFFFFF);
const _transparent = Color(0x00000000);

/// Extra Carp colors that Material's ColorScheme does not have.
/// Use: `context.palette.success`.
@immutable
class CarpPalette extends ThemeExtension<CarpPalette> {
  const CarpPalette({
    required this.success,
    required this.successText,
    required this.warning,
    required this.warningText,
    required this.owes,
    required this.owesText,
    required this.highlight,
    required this.highlightText,
    required this.card,
  });

  /// Credits, confirmed payments (icons and fills).
  final Color success;
  final Color successText;

  /// Pending payments.
  final Color warning;
  final Color warningText;

  /// Amounts owed.
  final Color owes;
  final Color owesText;

  /// Sunny orange: highlights, badges, "Coming soon" tags.
  final Color highlight;
  final Color highlightText;

  final Color card;

  static const light = CarpPalette(
    success: _Light.success,
    successText: _Light.successText,
    warning: _Light.warning,
    warningText: _Light.warningText,
    owes: _Light.error,
    owesText: _Light.errorText,
    highlight: _Light.secondary,
    highlightText: _Light.secondaryText,
    card: _Light.card,
  );

  static const dark = CarpPalette(
    success: _Dark.success,
    successText: _Dark.success,
    warning: _Dark.warning,
    warningText: _Dark.warning,
    owes: _Dark.error,
    owesText: _Dark.error,
    highlight: _Dark.secondary,
    highlightText: _Dark.secondary,
    card: _Dark.card,
  );

  @override
  CarpPalette copyWith() => this;

  @override
  CarpPalette lerp(CarpPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return CarpPalette(
      success: mix(success, other.success),
      successText: mix(successText, other.successText),
      warning: mix(warning, other.warning),
      warningText: mix(warningText, other.warningText),
      owes: mix(owes, other.owes),
      owesText: mix(owesText, other.owesText),
      highlight: mix(highlight, other.highlight),
      highlightText: mix(highlightText, other.highlightText),
      card: mix(card, other.card),
    );
  }
}

extension CarpThemeContext on BuildContext {
  CarpPalette get palette => Theme.of(this).extension<CarpPalette>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
}

ColorScheme _scheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  // Material 3 base from the seed, then our exact brand colors on top.
  final base = ColorScheme.fromSeed(seedColor: _Light.primary, brightness: brightness);
  return isDark
      ? base.copyWith(
          primary: _Dark.primary,
          onPrimary: _Dark.onBright,
          secondary: _Dark.secondary,
          onSecondary: _Dark.onBright,
          tertiary: _Dark.success,
          onTertiary: _Dark.onBright,
          tertiaryContainer: _Dark.highlightSoft,
          onTertiaryContainer: _Dark.onHighlightSoft,
          error: _Dark.error,
          onError: _Dark.onBright,
          surface: _Dark.background,
          onSurface: _Dark.text,
          onSurfaceVariant: _Dark.textMuted,
          outline: _Dark.outline,
          outlineVariant: _Dark.outlineSoft,
          surfaceContainerLowest: _Dark.background,
          surfaceContainerLow: _Dark.card,
          surfaceContainer: _Dark.card,
          surfaceContainerHigh: _Dark.container,
          surfaceContainerHighest: _Dark.outlineSoft,
          surfaceTint: _transparent,
        )
      : base.copyWith(
          primary: _Light.primary,
          onPrimary: _white,
          secondary: _Light.secondary,
          onSecondary: _darkTextOnOrange,
          tertiary: _Light.success,
          onTertiary: _white,
          tertiaryContainer: _Light.highlightSoft,
          onTertiaryContainer: _Light.onHighlightSoft,
          error: _Light.errorText,
          onError: _white,
          surface: _Light.background,
          onSurface: _Light.text,
          onSurfaceVariant: _Light.textMuted,
          outline: _Light.outline,
          outlineVariant: _Light.outlineSoft,
          surfaceContainerLowest: _white,
          surfaceContainerLow: _Light.background,
          surfaceContainer: _Light.container,
          surfaceContainerHigh: _Light.container,
          surfaceContainerHighest: _Light.outlineSoft,
          surfaceTint: _transparent,
        );
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = _scheme(brightness);
  final palette = brightness == Brightness.dark ? CarpPalette.dark : CarpPalette.light;
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness);
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

  return base.copyWith(
    extensions: [palette],
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: _transparent,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
      actionsIconTheme: IconThemeData(color: scheme.primary),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Gap.radius),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(backgroundColor: palette.card),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.card,
      indicatorColor: scheme.primary.withValues(alpha: 0.16),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
          )),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? scheme.primary : _transparent),
        foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? scheme.onPrimary : scheme.onSurface),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainer,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: rounded,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: rounded,
        side: BorderSide(color: scheme.outline),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
  );
}
