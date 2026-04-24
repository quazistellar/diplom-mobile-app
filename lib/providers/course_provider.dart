import 'package:flutter/foundation.dart';
import '../models/course.dart';
import '../services/api_client.dart';

class CourseProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  
  bool _isLoading = false;
  String? _errorMessage;
  List<Course> _allCourses = [];
  List<Course> _userCourses = [];
  List<Course> _popularCourses = [];
  

  String? _currentSearchQuery;
  List<int> _selectedCategoryIds = [];
  List<int> _selectedTypeIds = [];
  bool? _currentHasCertificate;
  bool? _currentFreeOnly;
  String? _currentSortBy;
  String _currentSortOrder = 'asc';
  
  List<CourseCategory> _courseCategories = [];
  List<CourseType> _courseTypes = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Course> get allCourses => _allCourses;
  List<Course> get userCourses => _userCourses;
  List<Course> get popularCourses => _popularCourses;
  List<CourseCategory> get courseCategories => _courseCategories;
  List<CourseType> get courseTypes => _courseTypes;

  String? get currentSearchQuery => _currentSearchQuery;
  List<int> get selectedCategoryIds => _selectedCategoryIds;
  List<int> get selectedTypeIds => _selectedTypeIds;
  bool? get currentHasCertificate => _currentHasCertificate;
  bool? get currentFreeOnly => _currentFreeOnly;
  String? get currentSortBy => _currentSortBy;
  String get currentSortOrder => _currentSortOrder;

  /// данная функция загружает список категорий курсов
  Future<void> loadCourseCategories() async {
    try {
      final data = await _apiClient.get<Map<String, dynamic>>(
        '/course-categories/',
        isPublic: true,
      );
      final results = data['results'] as List? ?? [];
      _courseCategories = results
          .map((json) => CourseCategory.fromJson(json))
          .toList();
      notifyListeners();
    } catch (e) {
      print('Ошибка загрузки категорий: $e');
      _courseCategories = [];
    }
  }

  /// данная функция загружает список типов курсов
  Future<void> loadCourseTypes() async {
    try {
      final data = await _apiClient.get<Map<String, dynamic>>(
        '/course-types/',
        isPublic: true,
      );
      final results = data['results'] as List? ?? [];
      _courseTypes = results
          .map((json) => CourseType.fromJson(json))
          .toList();
      notifyListeners();
    } catch (e) {
      print('Ошибка загрузки типов: $e');
      _courseTypes = [];
    }
  }

  /// данная функция загружает список курсов с фильтрацией
  Future<void> fetchCourses({
    String? searchQuery,
    List<int>? categoryIds,
    List<int>? typeIds,
    bool? hasCertificate,
    bool? freeOnly,
    String? sortBy,
    String? sortOrder,
    bool resetFilters = false,
    bool popularOnly = false,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      if (resetFilters) {
        _resetAllFilters();
      } else {
        _updateFilters(
          searchQuery: searchQuery,
          categoryIds: categoryIds,
          typeIds: typeIds,
          hasCertificate: hasCertificate,
          freeOnly: freeOnly,
          sortBy: sortBy,
          sortOrder: sortOrder,
        );
      }

      final queryParams = <String, dynamic>{};
      
      if (popularOnly) {
        queryParams['sort_by'] = 'student_count';
        queryParams['sort_order'] = 'desc';
      }
      
      if (_currentSearchQuery?.isNotEmpty == true) {
        queryParams['search'] = _currentSearchQuery;
      }
      if (_selectedCategoryIds.isNotEmpty) {
        queryParams['course_category'] = _selectedCategoryIds.join(',');
      }
      if (_selectedTypeIds.isNotEmpty) {
        queryParams['course_type'] = _selectedTypeIds.join(',');
      }
      if (_currentHasCertificate != null) {
        queryParams['has_certificate'] = _currentHasCertificate.toString();
      }
      if (_currentFreeOnly == true) {
        queryParams['free_only'] = 'true';
      }
      if (_currentSortBy != null && !popularOnly) {
        queryParams['sort_by'] = _currentSortBy;
        queryParams['sort_order'] = _currentSortOrder;
      }

      final data = await _apiClient.get<Map<String, dynamic>>(
        '/courses/',
        queryParams: queryParams,
        isPublic: true,
      );
      
      final results = data['results'] as List? ?? [];
      final courses = results.map((json) => Course.fromJson(json)).toList();
      
      if (popularOnly) {
        _popularCourses = courses;
      } else {
        _allCourses = courses;
      }

    } catch (e) {
      _errorMessage = e.toString();
      if (popularOnly) {
        _popularCourses = [];
      } else {
        _allCourses = [];
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// данная функция загружает популярные курсы
  Future<void> fetchPopularCourses() async {
    await fetchCourses(popularOnly: true);
  }

  /// данная функция загружает курсы пользователя
  Future<void> loadUserCourses() async {
    if (!await _apiClient.isAuthenticated()) return;

    try {
      final data = await _apiClient.get<Map<String, dynamic>>('/user-courses/');
      final results = data['results'] as List? ?? [];
      _userCourses = results
          .map((json) => Course.fromJson(json))
          .toList();
      notifyListeners();
    } catch (e) {
      _userCourses = [];
    }
  }

  /// данная функция обновляет фильтры курсов
  Future<void> updateFilters({
    String? searchQuery,
    List<int>? categoryIds,
    List<int>? typeIds,
    bool? hasCertificate,
    bool? freeOnly,
    String? sortBy,
    String? sortOrder,
  }) async {
    _updateFilters(
      searchQuery: searchQuery,
      categoryIds: categoryIds,
      typeIds: typeIds,
      hasCertificate: hasCertificate,
      freeOnly: freeOnly,
      sortBy: sortBy,
      sortOrder: sortOrder,
    );
    await fetchCourses();
  }

  /// данная функция обновляет значения фильтров
  void _updateFilters({
    String? searchQuery,
    List<int>? categoryIds,
    List<int>? typeIds,
    bool? hasCertificate,
    bool? freeOnly,
    String? sortBy,
    String? sortOrder,
  }) {
    if (searchQuery != null) {
      _currentSearchQuery = searchQuery.isEmpty ? null : searchQuery;
    }
    if (categoryIds != null) {
      _selectedCategoryIds = List<int>.from(categoryIds);
    }
    if (typeIds != null) {
      _selectedTypeIds = List<int>.from(typeIds);
    }
    if (hasCertificate != null) {
      _currentHasCertificate = hasCertificate;
    }
    if (freeOnly != null) {
      _currentFreeOnly = freeOnly;
    }
    if (sortBy != null) {
      _currentSortBy = sortBy.isEmpty ? null : sortBy;
    }
    if (sortOrder != null) {
      _currentSortOrder = sortOrder;
    }
  }

  /// данная функция сбрасывает все фильтры
  void _resetAllFilters() {
    _currentSearchQuery = null;
    _selectedCategoryIds = [];
    _selectedTypeIds = [];
    _currentHasCertificate = null;
    _currentFreeOnly = null;
    _currentSortBy = null;
    _currentSortOrder = 'asc';
  }

  /// данная функция очищает все фильтры
  Future<void> clearAllFilters() async {
    _resetAllFilters();
    await fetchCourses();
  }

  /// данная функция очищает фильтр по категориям
  Future<void> clearCategoryFilter() async {
    _selectedCategoryIds = [];
    await fetchCourses();
  }

  /// данная функция очищает фильтр по типам
  Future<void> clearTypeFilter() async {
    _selectedTypeIds = [];
    await fetchCourses();
  }

  /// данная функция очищает фильтр по сертификатам
  Future<void> clearCertificateFilter() async {
    _currentHasCertificate = null;
    await fetchCourses();
  }

  /// данная функция очищает фильтр по бесплатным курсам
  Future<void> clearFreeOnlyFilter() async {
    _currentFreeOnly = null;
    await fetchCourses();
  }

  /// данная функция очищает сортировку
  Future<void> clearSorting() async {
    _currentSortBy = null;
    _currentSortOrder = 'asc';
    await fetchCourses();
  }

  /// данная функция переключает фильтр по категории
  void toggleCategoryFilter(int categoryId) {
    if (_selectedCategoryIds.contains(categoryId)) {
      _selectedCategoryIds.remove(categoryId);
    } else {
      _selectedCategoryIds.add(categoryId);
    }
  }

  /// данная функция переключает фильтр по типу
  void toggleTypeFilter(int typeId) {
    if (_selectedTypeIds.contains(typeId)) {
      _selectedTypeIds.remove(typeId);
    } else {
      _selectedTypeIds.add(typeId);
    }
  }

  /// данная функция проверяет записан ли пользователь на курс
  bool isUserEnrolled(int courseId) {
    return _userCourses.any((course) => course.id == courseId);
  }

  /// данная функция возвращает количество активных курсов
  int getActiveCoursesCount() {
    return _userCourses.where((course) => course.isCompleted != true).length;
  }

  /// данная функция возвращает количество завершенных курсов
  int getCompletedCoursesCount() {
    return _userCourses.where((course) => course.isCompleted == true).length;
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


  Course? _currentCourse;
  List<dynamic> _courseMaterials = [];
  int _totalLectures = 0;
  int _totalAssignments = 0;
  int _totalTests = 0;
  
  Course? get currentCourse => _currentCourse;
  List<dynamic> get courseMaterials => _courseMaterials;
  int get totalLectures => _totalLectures;
  int get totalAssignments => _totalAssignments;
  int get totalTests => _totalTests;

  /// данная функция загружает материалы курса
  Future<void> loadCourseMaterials(int courseId) async {
    _setLoading(true);
    _clearError();

    try {
      final data = await _apiClient.get<Map<String, dynamic>>(
        '/courses/$courseId/materials/',
        isPublic: true,
      );
      
      _currentCourse = Course.fromJson(data['course']);
      _courseMaterials = data['materials_by_lecture'] ?? [];
      _totalLectures = data['total_lectures'] ?? 0;
      _totalAssignments = data['total_assignments'] ?? 0;
      _totalTests = data['total_tests'] ?? 0;
      
      notifyListeners();
      
    } catch (e) {
      _errorMessage = e.toString();
      _courseMaterials = [];
    } finally {
      _setLoading(false);
    }
  }
}