import 'package:flutter/material.dart';

import '../services/theme_settings_service.dart';

@immutable
class JournalThemeColors extends ThemeExtension<JournalThemeColors> {
  final Color cardBackground;
  final Color sectionHeader;
  final Color accentDark;
  final Color inputBorder;
  final Color cardDivider;

  const JournalThemeColors({
    required this.cardBackground,
    required this.sectionHeader,
    required this.accentDark,
    required this.inputBorder,
    required this.cardDivider,
  });

  @override
  JournalThemeColors copyWith({
    Color? cardBackground,
    Color? sectionHeader,
    Color? accentDark,
    Color? inputBorder,
    Color? cardDivider,
  }) {
    return JournalThemeColors(
      cardBackground: cardBackground ?? this.cardBackground,
      sectionHeader: sectionHeader ?? this.sectionHeader,
      accentDark: accentDark ?? this.accentDark,
      inputBorder: inputBorder ?? this.inputBorder,
      cardDivider: cardDivider ?? this.cardDivider,
    );
  }

  @override
  JournalThemeColors lerp(ThemeExtension<JournalThemeColors>? other, double t) {
    if (other is! JournalThemeColors) return this;
    return JournalThemeColors(
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      sectionHeader: Color.lerp(sectionHeader, other.sectionHeader, t)!,
      accentDark: Color.lerp(accentDark, other.accentDark, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      cardDivider: Color.lerp(cardDivider, other.cardDivider, t)!,
    );
  }
}

extension JournalThemeContext on BuildContext {
  JournalThemeColors get journalColors =>
      Theme.of(this).extension<JournalThemeColors>()!;
}

ThemeData buildAppTheme(AppThemeColor themeColor) {
  final material = themeColor.materialColor;
  final journalColors = JournalThemeColors(
    cardBackground: themeColor.cardBackground,
    sectionHeader: themeColor.sectionHeader,
    accentDark: themeColor.accentDark,
    inputBorder: material.shade300,
    cardDivider: material.shade100,
  );
  final cardBackground = journalColors.cardBackground;
  final inputBorder = journalColors.inputBorder;
  final cardDivider = journalColors.cardDivider;
  const inputBorderRadius = BorderRadius.all(Radius.circular(8));

  final colorScheme = ColorScheme.light(
    primary: material.shade700,
    onPrimary: Colors.white,
    primaryContainer: material.shade50,
    onPrimaryContainer: material.shade900,
    secondary: material.shade400,
    onSecondary: Colors.white,
    surface: Colors.white,
    onSurface: Colors.black87,
    outline: cardBackground,
    outlineVariant: cardBackground,
  );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    secondaryHeaderColor: cardBackground,
    dividerTheme: DividerThemeData(
      color: cardDivider,
      thickness: 1,
      space: 1,
    ),
    switchTheme: SwitchThemeData(
      trackOutlineWidth: WidgetStateProperty.all(0),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colorScheme.primary;
        }
        return material.shade100;
      }),
      thumbColor: WidgetStateProperty.all(Colors.white),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: colorScheme.primary),
        foregroundColor: colorScheme.primary,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cardDivider, width: 1),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: cardBackground,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: inputBorderRadius,
        borderSide: BorderSide(color: inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: inputBorderRadius,
        borderSide: BorderSide(color: inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: inputBorderRadius,
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    ),
    extensions: [journalColors],
  );
}
