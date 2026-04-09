import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//  Bigdogg Design System
// ─────────────────────────────────────────────

class AppColors {
  // Brand
  static const Color navy = Color(0xFF1A1A2E);
  static const Color navyDark = Color(0xFF0D0C1A);
  static const Color navyLight = Color(0xFF252552);
  static const Color indigo = Color(0xFF5B5BD6);
  static const Color indigoLight = Color(0xFF8787E0);

  // Backgrounds
  static const Color bgPage = Color(0xFFF4F6FF);
  static const Color bgSurface = Color(0xFFFFFFFF);
  static const Color bgInput = Color(0xFFF7F8FC);

  // Text
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color info = Color(0xFF3B82F6);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // Borders
  static const Color border = Color(0xFFE4E7F1);
  static const Color borderLight = Color(0xFFF0F2FA);
}

class AppGradients {
  static const LinearGradient navyHero = LinearGradient(
    colors: [Color(0xFF0D0C1A), Color(0xFF1A1A2E), Color(0xFF1E1D45)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient navySubtle = LinearGradient(
    colors: [Color(0xFF141426), Color(0xFF1A1A2E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient indigoAccent = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF3D3BAA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppShadows {
  static List<BoxShadow> card = [
    BoxShadow(
      color: const Color(0xFF1A1A2E).withOpacity(0.06),
      blurRadius: 16,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> loginCard = [
    BoxShadow(
      color: Colors.black.withOpacity(0.28),
      blurRadius: 64,
      offset: const Offset(0, 24),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> fab = [
    BoxShadow(
      color: const Color(0xFF1A1A2E).withOpacity(0.30),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}

class AppDecorations {
  static BoxDecoration card = BoxDecoration(
    color: AppColors.bgSurface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.border, width: 1),
    boxShadow: AppShadows.card,
  );

  static BoxDecoration primaryCard = BoxDecoration(
    gradient: AppGradients.navySubtle,
    borderRadius: BorderRadius.circular(16),
  );
}

// ─────────────────────────────────────────────
//  Shared Widgets
// ─────────────────────────────────────────────

/// A styled section header used in content screens
class SectionHeader extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;

  const SectionHeader(
    this.title, {
    super.key,
    this.padding = const EdgeInsets.only(bottom: 10),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// Gradient stat card for summary panels (expenses, overview header, etc.)
class GradientStatCard extends StatelessWidget {
  final List<_StatItem> stats;

  const GradientStatCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: const BoxDecoration(
        gradient: AppGradients.navySubtle,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Row(
        children: stats.map((s) {
          return Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.label,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  const _StatItem(this.label, this.value);
}

_StatItem statItem(String label, String value) => _StatItem(label, value);

/// Status badge for invoices
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge(this.status, {super.key});

  Color get _color {
    switch (status) {
      case 'paid':
        return AppColors.success;
      case 'sent':
        return AppColors.info;
      case 'overdue':
        return AppColors.danger;
      default:
        return AppColors.textMuted;
    }
  }

  String get _label {
    switch (status) {
      case 'paid':
        return 'Paid';
      case 'sent':
        return 'Sent';
      case 'overdue':
        return 'Overdue';
      default:
        return 'Draft';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _color.withOpacity(0.25), width: 1),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _color,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

/// Error message container
class ErrorBox extends StatelessWidget {
  final String message;
  const ErrorBox(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Success message container
class SuccessBox extends StatelessWidget {
  final String message;
  const SuccessBox(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF6EE7B7), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF065F46), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state widget
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Icon(icon, size: 36, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Theme Data
// ─────────────────────────────────────────────

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.navy,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFE8E9FF),
        onPrimaryContainer: AppColors.navy,
        secondary: AppColors.indigo,
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFEEEEFF),
        onSecondaryContainer: AppColors.indigo,
        tertiary: const Color(0xFF0EA5E9),
        onTertiary: Colors.white,
        tertiaryContainer: const Color(0xFFE0F2FE),
        onTertiaryContainer: const Color(0xFF0C4A6E),
        error: AppColors.danger,
        onError: Colors.white,
        errorContainer: const Color(0xFFFEE2E2),
        onErrorContainer: const Color(0xFF991B1B),
        background: AppColors.bgPage,
        onBackground: AppColors.textPrimary,
        surface: AppColors.bgSurface,
        onSurface: AppColors.textPrimary,
        outline: AppColors.border,
        outlineVariant: AppColors.borderLight,
        surfaceVariant: AppColors.bgInput,
        onSurfaceVariant: AppColors.textSecondary,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: AppColors.navy,
        onInverseSurface: Colors.white,
        inversePrimary: const Color(0xFFBBBBFF),
      ),
      scaffoldBackgroundColor: AppColors.bgPage,

      // AppBar
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
      ),

      // Card
      cardTheme: CardTheme(
        elevation: 0,
        color: AppColors.bgSurface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgInput,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.navy, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontFamily: 'Inter',
          fontSize: 14,
        ),
        floatingLabelStyle: const TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
          fontSize: 13,
        ),
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontFamily: 'Inter',
          fontSize: 14,
        ),
      ),

      // Elevated button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
            letterSpacing: 0.1,
          ),
        ),
      ),

      // Text button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.navy,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
            fontSize: 14,
          ),
        ),
      ),

      // Outlined button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          side: const BorderSide(color: AppColors.navy),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        splashColor: Colors.white.withOpacity(0.12),
      ),

      // NavigationBar (M3)
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        indicatorColor: AppColors.navy.withOpacity(0.08),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
              color: AppColors.navy,
            );
          }
          return const TextStyle(
            fontSize: 10,
            fontFamily: 'Inter',
            color: AppColors.textMuted,
          );
        }),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: AppColors.navy, size: 22);
          }
          return const IconThemeData(color: AppColors.textMuted, size: 22);
        }),
      ),

      // Dialog
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.bgSurface,
        elevation: 12,
        shadowColor: Colors.black.withOpacity(0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontFamily: 'Inter',
        ),
      ),

      // Snack bar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontFamily: 'Inter',
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 8,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 1,
      ),

      // List tile
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 8,
      ),

      // Progress indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.navy,
      ),

      // Tab bar
      tabBarTheme: const TabBarTheme(
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
          fontSize: 14,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
          fontSize: 14,
        ),
        indicatorSize: TabBarIndicatorSize.label,
      ),
    );
  }
}
