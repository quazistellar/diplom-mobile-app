import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../models/favorite.dart';

class FavoriteProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  
  List<FavoriteCourse> _favorites = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _favoritesCount = 0;

  List<FavoriteCourse> get favorites => _favorites;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get favoritesCount => _favoritesCount;

  /// данная функция очищает данные при выходе из аккаунта
  void clearData() {
    _favorites = [];
    _favoritesCount = 0;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// данная функция загружает список избранных курсов
  Future<void> loadFavorites() async {
    if (!await _apiClient.isAuthenticated()) return;
    
    _setLoading(true);
    _clearError();

    try {
      final data = await _apiClient.get<Map<String, dynamic>>(
        '/favorites/list/',
      );
      
      final results = data['results'] as List? ?? [];
      _favorites = results
          .map((json) => FavoriteCourse.fromJson(json))
          .toList();
      _favoritesCount = _favorites.length;
      
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _favorites = [];
      _favoritesCount = 0;
    } finally {
      _setLoading(false);
    }
  }

  /// данная функция переключает статус избранного для курса
  Future<bool> toggleFavorite(int courseId) async {
    if (!await _apiClient.isAuthenticated()) {
      _errorMessage = 'Необходимо войти в систему';
      notifyListeners();
      return false;
    }

    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/favorites/toggle/',
        data: {'course_id': courseId},
      );
      
      final isFavorited = response['is_favorited'] ?? false;
      
      if (isFavorited) {
        await loadFavorites();
      } else {
        _favorites.removeWhere((fav) => fav.id == courseId);
        _favoritesCount = _favorites.length;
        notifyListeners();
      }
      
      return isFavorited;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// данная функция проверяет, добавлен ли курс в избранное
  Future<bool> isFavorited(int courseId) async {
    if (!await _apiClient.isAuthenticated()) return false;
    
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/favorites/check/',
        queryParams: {'course_id': courseId},
      );
      return response['is_favorited'] ?? false;
    } catch (e) {
      return false;
    }
  }

  /// получение количества избранных курсов
  Future<int> getFavoritesCount() async {
    if (!await _apiClient.isAuthenticated()) return 0;
    
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/favorites/count/',
      );
      final count = response['count'] ?? 0;
      _favoritesCount = count;
      notifyListeners();
      return count;
    } catch (e) {
      return _favoritesCount;
    }
  }

  /// удаление курса из избранного
  Future<bool> removeFavorite(int courseId) async {
    return toggleFavorite(courseId);
  }

  /// функция очищения ошибки
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// функция установки загрузки
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// функция очищения ошибки
  void _clearError() {
    _errorMessage = null;
  }
}