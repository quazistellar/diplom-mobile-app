import 'package:flutter/material.dart';

class NavigationProvider with ChangeNotifier {
  int _currentIndex = 0;

  /// данная функция возвращает текущий индекс навигации
  int get currentIndex => _currentIndex;

  /// данная функция устанавливает текущий индекс навигации
  set currentIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  /// данная функция сбрасывает навигацию на главный экран
  void resetToHome() {
    _currentIndex = 0;
    notifyListeners();
  }
}