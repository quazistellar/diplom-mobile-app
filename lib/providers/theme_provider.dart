import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ThemeManager with ChangeNotifier {
  static const String _themeKey = 'app_theme';
  static const String _rememberMeKey = 'remember_me';
  static const String _fontSizeKey = 'font_size';
  
  ThemeMode _themeMode = ThemeMode.dark;
  bool _rememberMe = false;
  String _fontSize = 'Стандартный';

  ThemeMode get themeMode => _themeMode;
  bool get rememberMe => _rememberMe;
  String get fontSize => _fontSize;
  
  ThemeData get currentTheme {
    final baseTheme = _themeMode == ThemeMode.dark 
        ? AppTheme.darkTheme 
        : AppTheme.lightTheme;
    
    return _applyFontSize(baseTheme);
  }
  
  ThemeManager() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final themeIndex = prefs.getInt(_themeKey) ?? ThemeMode.dark.index;
      _themeMode = ThemeMode.values[themeIndex];
      
      _rememberMe = prefs.getBool(_rememberMeKey) ?? false;
      
      _fontSize = prefs.getString(_fontSizeKey) ?? 'Стандартный';
      
      notifyListeners();
    } catch (e) {
      print('Error loading preferences: $e');
    }
  }

  Future<void> setTheme(ThemeMode theme) async {
    _themeMode = theme;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, theme.index);
    } catch (e) {
      print('Error saving theme: $e');
    }
  }

  Future<void> setRememberMe(bool value) async {
    _rememberMe = value;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_rememberMeKey, value);
    } catch (e) {
      print('Error saving remember me: $e');
    }
  }

  Future<void> setFontSize(String fontSize) async {
    _fontSize = fontSize;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fontSizeKey, fontSize);
    } catch (e) {
      print('Error saving font size: $e');
    }
  }

  void toggleTheme() {
    final newTheme = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setTheme(newTheme);
  }

  double _getFontScaleFactor() {
    switch (_fontSize) {
      case 'Мелкий':
        return 0.85;
      case 'Крупный':
        return 1.15;
      case 'Стандартный':
      default:
        return 1.0;
    }
  }

  ThemeData _applyFontSize(ThemeData baseTheme) {
    final scale = _getFontScaleFactor();
    
    return baseTheme.copyWith(
      textTheme: TextTheme(
        displayLarge: baseTheme.textTheme.displayLarge!.copyWith(
          fontSize: AppTheme.displayLargeSize * scale,
        ),
        displayMedium: baseTheme.textTheme.displayMedium!.copyWith(
          fontSize: AppTheme.displayMediumSize * scale,
        ),
        displaySmall: baseTheme.textTheme.displaySmall!.copyWith(
          fontSize: AppTheme.displaySmallSize * scale,
        ),
        titleLarge: baseTheme.textTheme.titleLarge!.copyWith(
          fontSize: AppTheme.titleLargeSize * scale,
        ),
        titleMedium: baseTheme.textTheme.titleMedium!.copyWith(
          fontSize: AppTheme.titleMediumSize * scale,
        ),
        titleSmall: baseTheme.textTheme.titleSmall!.copyWith(
          fontSize: AppTheme.titleSmallSize * scale,
        ),
        bodyLarge: baseTheme.textTheme.bodyLarge!.copyWith(
          fontSize: AppTheme.bodyLargeSize * scale,
        ),
        bodyMedium: baseTheme.textTheme.bodyMedium!.copyWith(
          fontSize: AppTheme.bodyMediumSize * scale,
        ),
        bodySmall: baseTheme.textTheme.bodySmall!.copyWith(
          fontSize: AppTheme.bodySmallSize * scale,
        ),
        labelLarge: baseTheme.textTheme.labelLarge!.copyWith(
          fontSize: AppTheme.labelLargeSize * scale,
        ),
        labelMedium: baseTheme.textTheme.labelMedium!.copyWith(
          fontSize: AppTheme.labelMediumSize * scale,
        ),
        labelSmall: baseTheme.textTheme.labelSmall!.copyWith(
          fontSize: AppTheme.labelSmallSize * scale,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: baseTheme.primaryColor,
          foregroundColor: Colors.white,
          textStyle: TextStyle(
            fontSize: AppTheme.labelLargeSize * scale,
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
      appBarTheme: baseTheme.appBarTheme.copyWith(
        titleTextStyle: TextStyle(
          fontSize: AppTheme.titleLargeSize * scale,
          fontWeight: FontWeight.w900,
          color: baseTheme.colorScheme.onSurface,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}