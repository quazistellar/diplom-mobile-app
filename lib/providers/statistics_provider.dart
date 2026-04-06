import 'package:flutter/foundation.dart';
import '../services/api_client.dart';

class StatisticsProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic> _statistics = {};

  Map<String, dynamic> get statistics => _statistics;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// данная функция загружает статистику платформы
  Future<void> loadStatistics() async {
    _setLoading(true);
    _clearError();

    try {
      final isAuthenticated = await _apiClient.isAuthenticated();
      
      if (isAuthenticated) {
        _statistics = await _apiClient.get<Map<String, dynamic>>('/statistics/');
      } else {
        _statistics = {
          'total_users': 0,
          'total_courses': 0,
          'total_enrollments': 0,
          'total_certificates': 0,
          'active_users': 0,
          'average_rating': 0.0,
        };
      }
    } catch (e) {
      _errorMessage = e.toString();
      _statistics = {
        'total_users': 0,
        'total_courses': 0,
        'total_enrollments': 0,
        'total_certificates': 0,
        'active_users': 0,
        'average_rating': 0.0,
      };
    } finally {
      _setLoading(false);
    }
  }

  /// данная функция возвращает общее количество пользователей
  int getTotalUsers() => _statistics['total_users'] ?? 0;
  
  /// данная функция возвращает общее количество курсов
  int getTotalCourses() => _statistics['total_courses'] ?? 0;
  
  /// данная функция возвращает общее количество записей на курсы
  int getTotalEnrollments() => _statistics['total_enrollments'] ?? 0;
  
  /// данная функция возвращает общее количество сертификатов
  int getTotalCertificates() => _statistics['total_certificates'] ?? 0;
  
  /// данная функция возвращает количество активных пользователей
  int getActiveUsers() => _statistics['active_users'] ?? 0;
  
  /// данная функция возвращает средний рейтинг
  double getAverageRating() {
    final rating = _statistics['average_rating'] ?? 0.0;
    if (rating is num) return rating.toDouble();
    if (rating is String) return double.tryParse(rating) ?? 0.0;
    return 0.0;
  }

  /// данная функция очищает сообщение об ошибке
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// данная функция устанавливает состояние загрузки
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// данная функция очищает ошибку
  void _clearError() {
    _errorMessage = null;
  }
}