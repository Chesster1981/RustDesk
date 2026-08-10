import 'package:flutter/material.dart';

/// Colors aligned with BetterDesk RdClient dark dashboard.
class RdHomeTheme {
  RdHomeTheme._();

  static const Color bg = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surface2 = Color(0xFF21262D);
  static const Color border = Color(0xFF30363D);
  static const Color accent = Color(0xFF58A6FF);
  static const Color accentSolid = Color(0xFF1F6FEB);
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textMuted = Color(0xFF8B949E);
  static const Color online = Color(0xFF3FB950);
  static const Color warn = Color(0xFFD29922);

  static BoxDecoration panel({double radius = 10}) => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
      );
}
