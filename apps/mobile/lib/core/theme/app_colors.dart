import 'package:flutter/material.dart';

/// Hand-authored design tokens for the "CricketArena" visual identity —
/// extracted from the 18-screen CricketArena UI mockup (navy hero/header,
/// bright-blue primary CTAs, green live/positive accents). Screens should
/// reference these instead of raw `Colors.*` so the palette stays
/// consistent as more screens are redesigned. Previously a green
/// "CricLeague" identity (`primary` = 0xFF16A34A) — that hex now lives on
/// `live`/`positive` instead, so `live` reads as green (matching the
/// mockup's "Live" badges) rather than its old red.
class AppColors {
  AppColors._();

  // Brand
  static const primary = Color(0xFF2563EB); // CTA buttons, active nav, links
  static const primaryLight = Color(0xFF3B82F6); // lighter blue accents
  static const primaryDark = Color(0xFF1D4ED8);

  // Navy hero/header surfaces (splash/login/register backgrounds, dark
  // cards) — also still used for the sidebar/drawer header.
  static const navy = Color(0xFF0F1B3D);
  static const navySurface = Color(0xFF1E293B);

  // Neutral surfaces
  static const pageBackground = Color(0xFFF8FAFC);
  static const cardBackground = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);

  // Text
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);

  // Semantic / status accents
  static const live = Color(0xFF16A34A);
  static const info = Color(0xFF3B82F6);
  static const purple = Color(0xFF8B5CF6);
  static const orange = Color(0xFFF97316);
  static const amber = Color(0xFFF59E0B);
  static const teal = Color(0xFF0F766E);
  static const tealDark = Color(0xFF134E4A);

  /// Positive/negative deltas (NRR, revenue change, profit).
  static const positive = Color(0xFF16A34A);
  static const negative = Color(0xFFDC2626);

  /// Rotating accent set for stat-card icon badges / chart legends, in the
  /// order used across the dashboard mockup (Tournaments/Teams/Players/
  /// Matches, Revenue breakdown segments, etc).
  static const accents = <Color>[purple, info, primary, orange, teal, amber];
}
