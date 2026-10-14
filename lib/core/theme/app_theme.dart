import 'package:flutter/material.dart';

/// Clinical Calm. Teal is the DigiMed Connect brand colour.
const Color digimedTeal = Color(0xFF0F766E);
const Color digimedTealDark = Color(0xFF115E59);
const Color digimedInk = Color(0xFF1F2933);
const Color digimedMist = Color(0xFFF4F7F6);

ThemeData buildDigimedTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: isDark ? const Color(0xFF5EEAD4) : digimedTeal,
    onPrimary: isDark ? const Color(0xFF042F2E) : Colors.white,
    secondary: isDark ? const Color(0xFF99F6E4) : digimedTealDark,
    onSecondary: isDark ? const Color(0xFF042F2E) : Colors.white,
    error: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB42318),
    onError: isDark ? const Color(0xFF450A0A) : Colors.white,
    surface: isDark ? const Color(0xFF10201E) : digimedMist,
    onSurface: isDark ? const Color(0xFFE7F3F1) : digimedInk,
    primaryContainer: isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1),
    onPrimaryContainer: isDark ? const Color(0xFFCCFBF1) : const Color(0xFF134E4A),
    secondaryContainer: isDark ? const Color(0xFF1C3532) : const Color(0xFFE6F4F1),
    onSecondaryContainer: isDark ? const Color(0xFFD1FAF5) : digimedTealDark,
    surfaceContainerHighest: isDark
        ? const Color(0xFF1C3532)
        : const Color(0xFFE7EEEC),
    outline: isDark ? const Color(0xFF3F5E5A) : const Color(0xFFB7C9C5),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: isDark ? const Color(0xFF17302D) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF17302D) : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, color: scheme.onSurface),
      ),
    ),
  );
}
