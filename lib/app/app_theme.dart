import 'package:flutter/material.dart';

abstract final class AppTokens {
  static const double radiusSm = 12;
  static const double radiusMd = 18;
  static const double radiusLg = 24;
  static const double page = 16;
  static const double gap = 12;
  static const double compactGap = 8;
}

abstract final class AppColors {
  static const brand = Color(0xFF138A63);
  static const brandDark = Color(0xFF54D7A0);
  static const lightAccentSoft = Color(0xFFEFF2F4);
  static const darkAccentSoft = Color(0xFF252A31);

  static const lightBackground = Color(0xFFF4F5F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceMuted = Color(0xFFF0F2F4);
  static const lightBorder = Color(0xFFDDE1E5);
  static const lightText = Color(0xFF171A1F);
  static const lightTextMuted = Color(0xFF626A73);

  static const darkBackground = Color(0xFF0B0D10);
  static const darkSurface = Color(0xFF15181D);
  static const darkSurfaceMuted = Color(0xFF1D2127);
  static const darkBorder = Color(0xFF2B3038);
  static const darkText = Color(0xFFF3F5F7);
  static const darkTextMuted = Color(0xFFA8B0BA);
}

abstract final class AppTheme {
  static final light = _theme(Brightness.light);
  static final dark = _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final brand = isLight ? AppColors.brand : AppColors.brandDark;
    final background = isLight ? AppColors.lightBackground : AppColors.darkBackground;
    final surface = isLight ? AppColors.lightSurface : AppColors.darkSurface;
    final surfaceMuted = isLight ? AppColors.lightSurfaceMuted : AppColors.darkSurfaceMuted;
    final border = isLight ? AppColors.lightBorder : AppColors.darkBorder;
    final text = isLight ? AppColors.lightText : AppColors.darkText;
    final textMuted = isLight ? AppColors.lightTextMuted : AppColors.darkTextMuted;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: brand,
      onPrimary: Colors.white,
      primaryContainer: isLight ? AppColors.lightAccentSoft : AppColors.darkAccentSoft,
      onPrimaryContainer: text,
      secondary: isLight ? const Color(0xFF55616D) : const Color(0xFFB7C0CA),
      onSecondary: isLight ? Colors.white : const Color(0xFF111418),
      secondaryContainer: surfaceMuted,
      onSecondaryContainer: text,
      tertiary: isLight ? const Color(0xFF385873) : const Color(0xFF9DC8EA),
      onTertiary: isLight ? Colors.white : const Color(0xFF0D1720),
      error: isLight ? const Color(0xFFB3261E) : const Color(0xFFFFB4AB),
      onError: isLight ? Colors.white : const Color(0xFF690005),
      surface: surface,
      onSurface: text,
      surfaceContainerLowest: surface,
      surfaceContainerLow: surface,
      surfaceContainer: surfaceMuted,
      surfaceContainerHigh: surfaceMuted,
      surfaceContainerHighest: isLight ? const Color(0xFFE8EBEE) : const Color(0xFF242931),
      outline: isLight ? const Color(0xFF9AA3AC) : const Color(0xFF727C87),
      outlineVariant: border,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: isLight ? const Color(0xFF2B3036) : const Color(0xFFE4E7EA),
      onInverseSurface: isLight ? const Color(0xFFF6F7F8) : const Color(0xFF20242A),
      inversePrimary: brand,
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      dividerColor: border,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: IconThemeData(color: text),
        titleTextStyle: TextStyle(color: text, fontWeight: FontWeight.w800, fontSize: 22),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: TextStyle(color: textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: brand, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: isLight ? const Color(0xFFE9EDF0) : const Color(0xFF2A2F36),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        labelStyle: TextStyle(color: text),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: isLight ? const Color(0xFFE7EAED) : const Color(0xFF252A31),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          color: states.contains(WidgetState.selected) ? brand : textMuted,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
        )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? brand : textMuted,
        )),
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface, surfaceTintColor: Colors.transparent),
      dialogTheme: DialogThemeData(backgroundColor: surface, surfaceTintColor: Colors.transparent),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          backgroundColor: brand,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          foregroundColor: brand,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
