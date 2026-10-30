import 'package:flutter/material.dart';

/// Brand tokens copied from the DigiMed Connect website
/// (healthcare-frontend src/theme/tokens.js, Option B "Patient Teal, Practice Blue").
class DigimedBrand {
  static const patient = Color(0xFF0F766E);
  static const patientHover = Color(0xFF115E59);
  static const patientPressed = Color(0xFF134E4A);
  static const patientTint = Color(0xFFE6F2EF);
  static const practice = Color(0xFF1D4E89);
  static const practiceHover = Color(0xFF163D6B);
  static const onPractice = Color(0xFFE2EBF0);
  static const background = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFD3DAE3);
  static const controlBorder = Color(0xFF687789);
  static const heading = Color(0xFF0B1F33);
  static const body = Color(0xFF2E3A4A);
  static const muted = Color(0xFF536072);
  static const error = Color(0xFFC0262D);
  static const errorBg = Color(0xFFFDEEEF);
  static const infoBg = Color(0xFFEAF1FA);

  // Website dark palette.
  static const darkPrimary = Color(0xFF2DD4BF);
  static const darkSecondary = Color(0xFF94A3B8);
  static const darkBackground = Color(0xFF0B1220);
  static const darkSurface = Color(0xFF152033);
  static const darkText = Color(0xFFE2E8F0);
  static const darkError = Color(0xFFF87171);
}

/// Kept for existing references.
const Color digimedTeal = DigimedBrand.patient;
const Color digimedTealDark = DigimedBrand.patientHover;
const Color digimedInk = DigimedBrand.heading;
const Color digimedMist = DigimedBrand.background;

/// Builds the app theme. [practice] uses the website's practice blue as the
/// action colour, the same as the web staff pages. The logo stays teal.
ThemeData buildDigimedTheme(Brightness brightness, {bool practice = false}) {
  final isDark = brightness == Brightness.dark;
  final lightPrimary = practice ? DigimedBrand.practice : DigimedBrand.patient;
  final lightPrimaryHover = practice ? DigimedBrand.practiceHover : DigimedBrand.patientHover;
  final lightTint = practice ? DigimedBrand.infoBg : DigimedBrand.patientTint;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: isDark ? DigimedBrand.darkPrimary : lightPrimary,
    onPrimary: isDark ? const Color(0xFF042F2E) : Colors.white,
    secondary: isDark ? DigimedBrand.darkSecondary : (practice ? DigimedBrand.patient : DigimedBrand.practice),
    onSecondary: isDark ? DigimedBrand.darkBackground : Colors.white,
    error: isDark ? DigimedBrand.darkError : DigimedBrand.error,
    onError: isDark ? const Color(0xFF450A0A) : Colors.white,
    errorContainer: isDark ? const Color(0xFF3B1215) : DigimedBrand.errorBg,
    surface: isDark ? DigimedBrand.darkBackground : DigimedBrand.background,
    onSurface: isDark ? DigimedBrand.darkText : DigimedBrand.body,
    onSurfaceVariant: isDark ? DigimedBrand.darkSecondary : DigimedBrand.muted,
    primaryContainer: isDark ? const Color(0xFF134E4A) : lightTint,
    onPrimaryContainer: isDark ? const Color(0xFFCCFBF1) : lightPrimaryHover,
    secondaryContainer: isDark ? const Color(0xFF1E2A3D) : DigimedBrand.patientTint,
    onSecondaryContainer: isDark ? DigimedBrand.darkText : DigimedBrand.patientPressed,
    surfaceContainerHighest: isDark ? const Color(0xFF1E2A3D) : const Color(0xFFEDF1F5),
    outline: isDark ? const Color(0xFF334155) : DigimedBrand.controlBorder,
    outlineVariant: isDark ? const Color(0xFF253247) : DigimedBrand.border,
  );
  final cardColour = isDark ? DigimedBrand.darkSurface : DigimedBrand.surface;
  final headingColour = isDark ? DigimedBrand.darkText : DigimedBrand.heading;
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  final text = base.textTheme.apply(bodyColor: scheme.onSurface, displayColor: headingColour);

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.3),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: cardColour,
      foregroundColor: headingColour,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      titleTextStyle: text.titleLarge?.copyWith(color: headingColour, fontWeight: FontWeight.w600),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: cardColour,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardColour,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: headingColour, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(textStyle: const TextStyle(fontWeight: FontWeight.w600)),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      labelStyle: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cardColour,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, color: scheme.onSurface),
      ),
    ),
  );
}
