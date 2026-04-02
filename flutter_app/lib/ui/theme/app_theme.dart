import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SlapColors {
  // Backgrounds
  static const bg = Color(0xFF0A0A0F);
  static const bgCard = Color(0xFF13131A);
  static const bgSurface = Color(0xFF1C1C28);

  // Neon Accents
  static const neonBlue = Color(0xFF00D4FF);
  static const neonPink = Color(0xFFFF006E);
  static const neonGreen = Color(0xFF00FF88);
  static const neonYellow = Color(0xFFFFE600);
  static const neonPurple = Color(0xFFBF5FFF);
  static const neonOrange = Color(0xFFFF6B00);

  // Players
  static const player1 = neonBlue;
  static const player2 = neonPink;

  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF8888AA);
  static const textMuted = Color(0xFF444466);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: SlapColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: SlapColors.neonBlue,
          secondary: SlapColors.neonPink,
          surface: SlapColors.bgCard,
          background: SlapColors.bg,
        ),
        textTheme: GoogleFonts.nunito TextTheme(
          displayLarge: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: SlapColors.textPrimary,
            letterSpacing: 2,
          ),
          displayMedium: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: SlapColors.textPrimary,
          ),
          headlineLarge: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: SlapColors.textPrimary,
          ),
          headlineMedium: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: SlapColors.textPrimary,
          ),
          bodyLarge: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: SlapColors.textPrimary,
          ),
          bodyMedium: const TextStyle(
            fontSize: 14,
            color: SlapColors.textSecondary,
          ),
        ),
        useMaterial3: true,
      );
}
