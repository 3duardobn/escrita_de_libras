import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF1F4E79);
  static const primaryLight = Color(0xFF3D6E9E);
  static const accent = Color(0xFFB45309);
  static const paper = Color(0xFFFFFFFF);

  static const lightBackground = Color(0xFFFBF9F6);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightMutedSurface = Color(0xFFF2EEE8);
  static const lightText = Color(0xFF1B1C1E);
  static const lightMuted = Color(0xFF64676C);
  static const lightOutline = Color(0xFFDCD5CA);

  static const darkBackground = Color(0xFF111418);
  static const darkSurface = Color(0xFF1A1E23);
  static const darkMutedSurface = Color(0xFF232830);
  static const darkText = Color(0xFFECEFF2);
  static const darkMuted = Color(0xFFA9B0B8);
  static const darkOutline = Color(0xFF343A43);
}

abstract final class AppRadius {
  static const double card = 18;
  static const double input = 14;
  static const double chip = 10;
}

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: isDark ? AppColors.primaryLight : AppColors.primary,
      secondary: AppColors.accent,
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
    ).copyWith(
      onSurface: isDark ? AppColors.darkText : AppColors.lightText,
      outline: isDark ? AppColors.darkOutline : AppColors.lightOutline,
      surfaceContainerLowest: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      surfaceContainerLow: isDark
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      surfaceContainer: isDark
          ? AppColors.darkMutedSurface
          : AppColors.lightMutedSurface,
      surfaceContainerHigh: isDark
          ? const Color(0xFF2A3038)
          : const Color(0xFFE9E3DA),
    );

    final textTheme = TextTheme(
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: scheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 23,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: scheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.5,
        color: scheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14.5,
        height: 1.5,
        color: scheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 12.5,
        height: 1.45,
        color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      labelMedium: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
      ),
      labelSmall: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? AppColors.darkBackground
            : AppColors.lightBackground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkMutedSurface : AppColors.lightSurface,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
          side: BorderSide(
            color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? AppColors.darkMutedSurface
            : AppColors.lightMutedSurface,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? AppColors.darkMutedSurface
            : AppColors.lightText,
        contentTextStyle: TextStyle(
          color: isDark ? AppColors.darkText : Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: isDark ? AppColors.darkMuted : AppColors.lightMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
