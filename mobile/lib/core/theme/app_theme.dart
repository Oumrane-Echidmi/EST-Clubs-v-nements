import 'package:flutter/material.dart';

/// Tokens taken from the Stitch design (docs/design/*.html tailwind config).
class AppColors {
  static const primary = Color(0xFF00236F);
  static const primaryContainer = Color(0xFF1E3A8A);
  static const secondary = Color(0xFF9D4300);
  static const secondaryContainer = Color(0xFFFD761A);
  static const tertiary = Color(0xFF00285E);
  static const surface = Color(0xFFF8F9FF);
  static const onSurface = Color(0xFF0B1C30);
  static const onSurfaceVariant = Color(0xFF444651);
  static const outline = Color(0xFF757682);
  static const outlineVariant = Color(0xFFC5C5D3);
  static const error = Color(0xFFBA1A1A);
}

class AppRadius {
  static const double sm = 8, md = 12, lg = 16, xl = 24;
}

class AppSpacing {
  static const double xs = 4, sm = 8, md = 16, lg = 24, xl = 32;
}

ThemeData buildTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primaryContainer,
    brightness: brightness,
  ).copyWith(
    primary: light ? AppColors.primary : null,
    secondary: light ? AppColors.secondary : null,
    secondaryContainer: AppColors.secondaryContainer,
    error: AppColors.error,
    surface: light ? AppColors.surface : null,
  );
  final theme = ThemeData(
    useMaterial3: true,
    fontFamily: "Inter", // bundled in assets/fonts
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    // Stitch look: flat surface app bar with a bold primary title.
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
          fontFamily: "PlusJakartaSans",
          color: scheme.primary, fontSize: 20, fontWeight: FontWeight.w800),
    ),
    // White rounded cards with a soft shadow.
    cardTheme: CardThemeData(
      color: light ? Colors.white : null,
      elevation: 1.5,
      shadowColor: Colors.black12,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: light ? Colors.white : null,
      indicatorColor: light ? const Color(0xFFDCE1FF) : null,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    ),
  );
  // Headlines use Plus Jakarta Sans (Stitch); everything else stays Inter.
  TextStyle? h(TextStyle? t) => t?.copyWith(fontFamily: "PlusJakartaSans");
  final t = theme.textTheme;
  return theme.copyWith(
    textTheme: t.copyWith(
      headlineLarge: h(t.headlineLarge),
      headlineMedium: h(t.headlineMedium),
      headlineSmall: h(t.headlineSmall),
      titleLarge: h(t.titleLarge),
    ),
  );
}
