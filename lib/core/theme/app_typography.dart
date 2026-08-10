import 'package:flutter/material.dart';

/// ──────────────────────────────────────────────────────────────────────────────
/// ZTransfer typography — clean, spacious, photography-tool feel.
/// Uses the system default font (Roboto on Android, SF Pro on iOS).
/// ──────────────────────────────────────────────────────────────────────────────

class AppTypography {
  AppTypography._();

  static const TextTheme textTheme = TextTheme(
    // Page titles
    headlineLarge: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
      height: 1.2,
    ),

    // Section headers
    headlineMedium: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.25,
      height: 1.3,
    ),

    // Card titles
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.4,
    ),

    // List item titles
    titleMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.4,
    ),

    // Body copy
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.15,
      height: 1.5,
    ),

    // Secondary body
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      height: 1.5,
    ),

    // Captions, metadata, EXIF labels
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      height: 1.5,
    ),

    // Monospace — used for file sizes, hex values, technical data
    labelLarge: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.4,
    ),

    labelMedium: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.4,
    ),

    labelSmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
      height: 1.4,
    ),
  );
}
