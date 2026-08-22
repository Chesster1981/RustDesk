import 'package:flutter/material.dart';

/// Colors aligned with BetterDesk RdClient; adapts to light/dark ThemeMode.
class RdHomeTheme {
  RdHomeTheme._();

  static const Color bgDark = Color(0xFF0D1117);
  static const Color surfaceDark = Color(0xFF161B22);
  static const Color surface2Dark = Color(0xFF21262D);
  static const Color borderDark = Color(0xFF30363D);
  static const Color textPrimaryDark = Color(0xFFE6EDF3);
  static const Color textMutedDark = Color(0xFF8B949E);

  static const Color bgLight = Color(0xFFF5F7FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surface2Light = Color(0xFFEEF1F5);
  static const Color borderLight = Color(0xFFD0D7DE);
  static const Color textPrimaryLight = Color(0xFF1F2328);
  static const Color textMutedLight = Color(0xFF656D76);

  static const Color accent = Color(0xFF58A6FF);
  static const Color accentSolid = Color(0xFF1F6FEB);
  static const Color online = Color(0xFF3FB950);
  static const Color warn = Color(0xFFD29922);

  // Back-compat aliases (dark defaults).
  static const Color bg = bgDark;
  static const Color surface = surfaceDark;
  static const Color surface2 = surface2Dark;
  static const Color border = borderDark;
  static const Color textPrimary = textPrimaryDark;
  static const Color textMuted = textMutedDark;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bgOf(BuildContext context) =>
      isDark(context) ? bgDark : bgLight;

  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? surfaceDark : surfaceLight;

  static Color surface2Of(BuildContext context) =>
      isDark(context) ? surface2Dark : surface2Light;

  static Color borderOf(BuildContext context) =>
      isDark(context) ? borderDark : borderLight;

  static Color textPrimaryOf(BuildContext context) =>
      isDark(context) ? textPrimaryDark : textPrimaryLight;

  static Color textMutedOf(BuildContext context) =>
      isDark(context) ? textMutedDark : textMutedLight;

  static BoxDecoration panel(BuildContext context, {double radius = 10}) =>
      BoxDecoration(
        color: surfaceOf(context),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderOf(context)),
      );
}
