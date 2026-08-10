import 'package:flutter/material.dart';

/// ──────────────────────────────────────────────────────────────────────────────
/// ZTransfer colour tokens — dark-forward, photography-tool palette.
/// No gradients, no glassmorphism.  Just clean, purposeful colours.
/// ──────────────────────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // ── Primary ────────────────────────────────────────────────────────────────

  /// Nikon yellow — the single accent colour used sparingly for CTAs and
  /// active-state indicators.
  static const Color accent = Color(0xFFFFD100);

  /// Darker variant for pressed states.
  static const Color accentPressed = Color(0xFFC9A300);

  // ── Surfaces (dark-first — the app launches in dark mode) ─────────────────

  static const Color background = Color(0xFF0D0D0D);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceElevated = Color(0xFF242424);
  static const Color surfaceHighlight = Color(0xFF2E2E2E);

  // ── Text ───────────────────────────────────────────────────────────────────

  static const Color textPrimary = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFF999999);
  static const Color textTertiary = Color(0xFF666666);

  // ── Status ─────────────────────────────────────────────────────────────────

  static const Color statusConnected = Color(0xFF4CAF50);
  static const Color statusDisconnected = Color(0xFF616161);
  static const Color statusError = Color(0xFFE53935);
  static const Color statusSyncing = Color(0xFFFFD100);
}
