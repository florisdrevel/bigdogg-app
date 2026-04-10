import 'package:flutter/material.dart';

class BigDoggTheme {
  // ─── Brand Colors ───────────────────────────────────────────
  static const Color teal900 = Color(0xFF0D2535);
  static const Color teal800 = Color(0xFF1B3A4B);
  static const Color teal700 = Color(0xFF2A5568);
  static const Color teal600 = Color(0xFF3A7090);
  static const Color teal400 = Color(0xFF6BA3BC);
  static const Color teal200 = Color(0xFFB8D4E0);
  static const Color teal100 = Color(0xFFE4F0F5);

  static const Color gold500 = Color(0xFFC9A96E);
  static const Color gold400 = Color(0xFFD9BF8A);
  static const Color gold300 = Color(0xFFE8D4A8);
  static const Color gold600 = Color(0xFFAA8A52);

  // ─── Light Mode ─────────────────────────────────────────────
  static const Color lightBg = Color(0xFFF5F3EF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFF0EDE8);
  static const Color lightBorder = Color(0xFFE2DDD6);
  static const Color lightTextPrimary = Color(0xFF1B3A4B);
  static const Color lightTextSecondary = Color(0xFF4A6572);
  static const Color lightTextHint = Color(0xFF8FA8B4);

  // ─── Dark Mode ──────────────────────────────────────────────
  static const Color darkBg = Color(0xFF1C1917);
  static const Color darkSurface = Color(0xFF292524);
  static const Color darkSurface2 = Color(0xFF352F2D);
  static const Color darkBorder = Color(0xFF44403C);
  static const Color darkTextPrimary = Color(0xFFF5F3EF);
  static const Color darkTextSecondary = Color(0xFFA8A29E);
  static const Color darkTextHint = Color(0xFF6B6663);

  // ─── Status Colors ──────────────────────────────────────────
  static const Color success = Color(0xFF059669);
  static const Color successBg = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorBg = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoBg = Color(0xFFDBEAFE);

  static ThemeData light() {
    return _buildTheme(
      brightness: Brightness.light,
      bg: lightBg,
      surface: lightSurface,
      surface2: lightSurface2,
      border: lightBorder,
      textPrimary: lightTextPrimary,
      textSecondary: lightTextSecondary,
      textHint: lightTextHint,
      appBarBg: teal800,
      appBarFg: Colors.white,
    );
  }

  static ThemeData dark() {
    return _buildTheme(
      brightness: Brightness.dark,
      bg: darkBg,
      surface: darkSurface,
      surface2: darkSurface2,
      border: darkBorder,
      textPrimary: darkTextPrimary,
      textSecondary: darkTextSecondary,
      textHint: darkTextHint,
      appBarBg: darkSurface,
      appBarFg: darkTextPrimary,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color surface2,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
    required Color textHint,
    required Color appBarBg,
    required Color appBarFg,
  }) {
    const String font = 'PlusJakartaSans';

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: font,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: teal800,
        onPrimary: Colors.white,
        secondary: gold500,
        onSecondary: Colors.white,
        error: error,
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        background: bg,
        onBackground: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: appBarFg,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          fontFamily: font,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: appBarFg),
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: teal800,
        unselectedItemColor: textHint,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontFamily: font,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: font,
          fontSize: 11,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: teal800,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFamily: font,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: teal800,
          side: const BorderSide(color: teal800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFamily: font,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: teal800,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: font,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: teal800, width: 2),
        ),
        labelStyle: TextStyle(color: textSecondary, fontFamily: font),
        hintStyle: TextStyle(color: textHint, fontFamily: font),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: teal800,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: CircleBorder(),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface2,
        labelStyle: TextStyle(fontFamily: font, fontSize: 12, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontFamily: font, letterSpacing: -1.5),
        displayMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontFamily: font, letterSpacing: -1.0),
        headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontFamily: font, letterSpacing: -0.8, fontSize: 28),
        headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontFamily: font, letterSpacing: -0.5, fontSize: 22),
        headlineSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontFamily: font, letterSpacing: -0.3, fontSize: 18),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontFamily: font, letterSpacing: -0.3, fontSize: 17),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontFamily: font, letterSpacing: -0.2, fontSize: 15),
        titleSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontFamily: font, fontSize: 13),
        bodyLarge: TextStyle(color: textPrimary, fontFamily: font, fontSize: 16),
        bodyMedium: TextStyle(color: textSecondary, fontFamily: font, fontSize: 14),
        bodySmall: TextStyle(color: textHint, fontFamily: font, fontSize: 12),
        labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontFamily: font, fontSize: 14),
        labelMedium: TextStyle(color: textSecondary, fontFamily: font, fontSize: 12),
        labelSmall: TextStyle(color: textHint, fontFamily: font, fontSize: 11),
      ),
    );
  }
}