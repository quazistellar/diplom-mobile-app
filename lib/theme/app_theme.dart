import 'package:flutter/material.dart';
/// данный класс содержит в себе цветовую тему и палитру приложения
class AppTheme {
  static const Color primaryColor = Color(0xFF8A4FFF);
  static const Color primaryDark = Color(0xFF6B31CC);
  static const Color accentColor = Color(0xFFFF4FD8);
  static const Color accentLight = Color(0xFFFF1980);
  
  static const Color backgroundDark = Color(0xFF0A1332);
  static const Color surfaceDark = Color(0xFF1A2357);
  static const Color textPrimaryDark = Color(0xFFE8EAFF);
  static const Color textSecondaryDark = Color(0xFFB8BFFF);
  static const Color borderDark = Color(0xFF2A3A7A);
  
  static const Color backgroundLight = Color(0xFFB0C9F9);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF2A1E5C);
  static const Color textSecondaryLight = Color(0xFF4A3D8C);
  static const Color borderLight = Color(0xFFE0E0E0);
  
  static const double displayLargeSize = 32;
  static const double displayMediumSize = 24;
  static const double displaySmallSize = 20;
  static const double titleLargeSize = 20;
  static const double titleMediumSize = 18;
  static const double titleSmallSize = 16;
  static const double bodyLargeSize = 16;
  static const double bodyMediumSize = 14;
  static const double bodySmallSize = 12;
  static const double labelLargeSize = 16;
  static const double labelMediumSize = 14;
  static const double labelSmallSize = 12;
  
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundDark,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: accentColor,
      surface: surfaceDark,
      background: backgroundDark,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimaryDark,
      onBackground: textPrimaryDark,
    ),
    
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: displayLargeSize,
        fontWeight: FontWeight.w900,
        color: textPrimaryDark,
        fontFamily: 'Inter',
      ),
      displayMedium: TextStyle(
        fontSize: displayMediumSize,
        fontWeight: FontWeight.w900,
        color: textPrimaryDark,
        fontFamily: 'Inter',
      ),
      displaySmall: TextStyle(
        fontSize: displaySmallSize,
        fontWeight: FontWeight.w900,
        color: textPrimaryDark,
        fontFamily: 'Inter',
      ),
      titleLarge: TextStyle(
        fontSize: titleLargeSize,
        fontWeight: FontWeight.w900,
        color: textPrimaryDark,
        fontFamily: 'Inter',
      ),
      titleMedium: TextStyle(
        fontSize: titleMediumSize,
        fontWeight: FontWeight.w900,
        color: textPrimaryDark,
        fontFamily: 'Inter',
      ),
      titleSmall: TextStyle(
        fontSize: titleSmallSize,
        fontWeight: FontWeight.w900,
        color: textPrimaryDark,
        fontFamily: 'Inter',
      ),
      bodyLarge: TextStyle(
        fontSize: bodyLargeSize,
        fontWeight: FontWeight.w500,
        color: textPrimaryDark,
        fontFamily: 'Inter',
      ),
      bodyMedium: TextStyle(
        fontSize: bodyMediumSize,
        fontWeight: FontWeight.w500,
        color: textSecondaryDark,
        fontFamily: 'Inter',
      ),
      bodySmall: TextStyle(
        fontSize: bodySmallSize,
        fontWeight: FontWeight.w500,
        color: textSecondaryDark,
        fontFamily: 'Inter',
      ),
      labelLarge: TextStyle(
        fontSize: labelLargeSize,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        fontFamily: 'Inter',
      ),
      labelMedium: TextStyle(
        fontSize: labelMediumSize,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        fontFamily: 'Inter',
      ),
      labelSmall: TextStyle(
        fontSize: labelSmallSize,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        fontFamily: 'Inter',
      ),
    ),
    
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontSize: labelLargeSize,
          fontWeight: FontWeight.w900,
          fontFamily: 'Inter',
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
      ),
    ),
    
    cardTheme: CardThemeData(
      color: surfaceDark,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderDark, width: 1),
      ),
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceDark,
      hintStyle: const TextStyle(color: textSecondaryDark, fontFamily: 'Inter'),
      labelStyle: const TextStyle(color: textPrimaryDark, fontWeight: FontWeight.w900, fontFamily: 'Inter'),
      floatingLabelStyle: const TextStyle(color: primaryColor, fontFamily: 'Inter'),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderDark, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderDark, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      prefixIconColor: primaryColor,
      suffixIconColor: textSecondaryDark,
    ),
    
    appBarTheme: const AppBarTheme(
      backgroundColor: surfaceDark,
      elevation: 4,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: titleLargeSize,
        fontWeight: FontWeight.w900,
        color: textPrimaryDark,
        fontFamily: 'Inter',
      ),
      toolbarTextStyle: TextStyle(
        color: textPrimaryDark,
        fontFamily: 'Inter',
      ),
    ),
    
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceDark,
      selectedItemColor: primaryColor,
      unselectedItemColor: textSecondaryDark,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Inter'),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Inter'),
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),
    
    dialogTheme: DialogThemeData(
      backgroundColor: surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      titleTextStyle: const TextStyle(
        fontSize: titleLargeSize,
        fontWeight: FontWeight.w900,
        color: textPrimaryDark,
        fontFamily: 'Inter',
      ),
      contentTextStyle: const TextStyle(
        color: textSecondaryDark,
        fontFamily: 'Inter',
      ),
    ),
    
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceDark,
      contentTextStyle: const TextStyle(
        color: textPrimaryDark,
        fontFamily: 'Inter',
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    
    dividerTheme: const DividerThemeData(
      color: borderDark,
      thickness: 1,
      space: 0,
    ),
  );
  
  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundLight,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: accentColor,
      surface: surfaceLight,
      background: backgroundLight,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimaryLight,
      onBackground: textPrimaryLight,
    ),
    
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: displayLargeSize,
        fontWeight: FontWeight.w900,
        color: textPrimaryLight,
        fontFamily: 'Inter',
      ),
      displayMedium: TextStyle(
        fontSize: displayMediumSize,
        fontWeight: FontWeight.w900,
        color: textPrimaryLight,
        fontFamily: 'Inter',
      ),
      displaySmall: TextStyle(
        fontSize: displaySmallSize,
        fontWeight: FontWeight.w900,
        color: textPrimaryLight,
        fontFamily: 'Inter',
      ),
      titleLarge: TextStyle(
        fontSize: titleLargeSize,
        fontWeight: FontWeight.w900,
        color: textPrimaryLight,
        fontFamily: 'Inter',
      ),
      titleMedium: TextStyle(
        fontSize: titleMediumSize,
        fontWeight: FontWeight.w900,
        color: textPrimaryLight,
        fontFamily: 'Inter',
      ),
      titleSmall: TextStyle(
        fontSize: titleSmallSize,
        fontWeight: FontWeight.w900,
        color: textPrimaryLight,
        fontFamily: 'Inter',
      ),
      bodyLarge: TextStyle(
        fontSize: bodyLargeSize,
        fontWeight: FontWeight.w500,
        color: textPrimaryLight,
        fontFamily: 'Inter',
      ),
      bodyMedium: TextStyle(
        fontSize: bodyMediumSize,
        fontWeight: FontWeight.w500,
        color: textSecondaryLight,
        fontFamily: 'Inter',
      ),
      bodySmall: TextStyle(
        fontSize: bodySmallSize,
        fontWeight: FontWeight.w500,
        color: textSecondaryLight,
        fontFamily: 'Inter',
      ),
      labelLarge: TextStyle(
        fontSize: labelLargeSize,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        fontFamily: 'Inter',
      ),
      labelMedium: TextStyle(
        fontSize: labelMediumSize,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        fontFamily: 'Inter',
      ),
      labelSmall: TextStyle(
        fontSize: labelSmallSize,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        fontFamily: 'Inter',
      ),
    ),
    
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontSize: labelLargeSize,
          fontWeight: FontWeight.w900,
          fontFamily: 'Inter',
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
      ),
    ),
    
    cardTheme: CardThemeData(
      color: surfaceLight,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderLight, width: 1),
      ),
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceLight,
      hintStyle: const TextStyle(color: textSecondaryLight, fontFamily: 'Inter'),
      labelStyle: const TextStyle(color: textPrimaryLight, fontWeight: FontWeight.w900, fontFamily: 'Inter'),
      floatingLabelStyle: const TextStyle(color: primaryColor, fontFamily: 'Inter'),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderLight, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderLight, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      prefixIconColor: primaryColor,
      suffixIconColor: textSecondaryLight,
    ),
    
    appBarTheme: const AppBarTheme(
      backgroundColor: surfaceLight,
      elevation: 4,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: titleLargeSize,
        fontWeight: FontWeight.w900,
        color: textPrimaryLight,
        fontFamily: 'Inter',
      ),
      toolbarTextStyle: TextStyle(
        color: textPrimaryLight,
        fontFamily: 'Inter',
      ),
    ),
    
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceLight,
      selectedItemColor: primaryColor,
      unselectedItemColor: textSecondaryLight,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Inter'),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Inter'),
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),
    
    dialogTheme: DialogThemeData(
      backgroundColor: surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      titleTextStyle: const TextStyle(
        fontSize: titleLargeSize,
        fontWeight: FontWeight.w900,
        color: textPrimaryLight,
        fontFamily: 'Inter',
      ),
      contentTextStyle: const TextStyle(
        color: textSecondaryLight,
        fontFamily: 'Inter',
      ),
    ),
    
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceLight,
      contentTextStyle: const TextStyle(
        color: textPrimaryLight,
        fontFamily: 'Inter',
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    
    dividerTheme: const DividerThemeData(
      color: borderLight,
      thickness: 1,
      space: 0,
    ),
  );
}