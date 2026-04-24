import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../models/course.dart';

class UserCourseProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  
  bool _isLoading = false;
  String? _errorMessage;
  List<Course> _userCourses = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Course> get userCourses => _userCourses;

  /// данная функция загружает курсы пользователя
  Future<void> loadUserCourses() async {
    if (!await _apiClient.isAuthenticated()) {
      _userCourses = [];
      notifyListeners();
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      final data = await _apiClient.get<Map<String, dynamic>>('/user-courses/');
      final results = data['results'] as List? ?? [];
      
      _userCourses = results.map((json) {
        if (json['course_details'] != null) {
          final courseJson = json['course_details'] as Map<String, dynamic>;
          
          courseJson['payment_id'] = json['payment_id'];
          courseJson['payment_date'] = json['payment_date'];
          courseJson['user_course_id'] = json['id'];
          
          return Course(
            id: courseJson['id'] ?? 0,
            name: courseJson['course_name'] ?? 'Неизвестный курс',
            description: courseJson['course_description'],
            price: double.tryParse(courseJson['course_price']?.toString() ?? '0') ?? 0,
            hours: courseJson['course_hours'] ?? 0,
            hasCertificate: courseJson['has_certificate'] ?? false,
            maxPlaces: courseJson['course_max_places'],
            rating: courseJson['rating']?.toDouble() ?? 0.0, 
            photoPath: courseJson['course_photo_path'],
            category: courseJson['category_details'] != null 
                ? CourseCategory.fromJson(courseJson['category_details'])
                : null,
            type: courseJson['type_details'] != null
                ? CourseType.fromJson(courseJson['type_details'])
                : null,
            isActive: courseJson['is_active'] ?? true,
            isCompleted: json['status_course'] ?? false,
            isEnrolled: true,
            isActiveEnrollment: json['is_active'] ?? true,
            paymentDate: json['payment_date'],
            paymentId: json['payment_id']?.toString(),
            userCourseId: json['id'],
            rawData: courseJson,
          );
        }
        
        return Course(
          id: json['course'] is int ? json['course'] : 0,
          name: 'Неизвестный курс',
          description: '',
          price: 0,
          hours: 0,
          hasCertificate: false,
          rating: 0.0, 
          isCompleted: json['status_course'] ?? false,
          isEnrolled: true,
          isActiveEnrollment: json['is_active'] ?? true,
          paymentDate: json['payment_date'],
          paymentId: json['payment_id']?.toString(),
          userCourseId: json['id'],
          rawData: json,
        );
      }).toList();
      
      print('Loaded user courses: ${_userCourses.map((c) => '${c.id} (active: ${c.isActiveEnrollment})').toList()}');
    } catch (e) {
      print('Error loading user courses: $e');
      _errorMessage = e.toString();
      _userCourses = [];
    } finally {
      _setLoading(false);
    }
  }

  /// данная функция проверяет, есть ли у пользователя запись на курс
  bool isUserEnrolled(int courseId) {
    return _userCourses.any((course) => course.id == courseId);
  }

  /// данная функция проверяет, активна ли запись пользователя на курс
  bool isUserActiveEnrolled(int courseId) {
    return _userCourses.any((course) => course.id == courseId && course.isActiveEnrollment == true);
  }

  /// данная функция получает курс из списка записанных
  Course? getUserCourse(int courseId) {
    try {
      return _userCourses.firstWhere((course) => course.id == courseId);
    } catch (e) {
      return null;
    }
  }

  /// данная функция выполняет запись пользователя на курс
  Future<void> enrollToCourse(int courseId) async {
    _setLoading(true);
    _clearError();

    try {
      print('Enrolling to course $courseId...');

      final data = await _apiClient.get<Map<String, dynamic>>(
        '/user-courses/',
        queryParams: {'course': courseId.toString()},
      );
      
      final results = data['results'] as List? ?? [];
      
      if (results.isNotEmpty) {
        final userCourseData = results.first;
        final userCourseId = userCourseData['id'];
        final isActive = userCourseData['is_active'] ?? false;
        
        print('Found existing enrollment: $userCourseId, current active: $isActive');
        
        if (isActive == true) {
          print('Enrollment already active');
        } else {
          
          final updateData = {
            'is_active': true,
            'user': userCourseData['user'],
            'course': userCourseData['course'],
            'registration_date': userCourseData['registration_date'],
            'status_course': userCourseData['status_course'] ?? false,
            'course_price': userCourseData['course_price'],
          };
          
          if (userCourseData['payment_date'] != null) {
            updateData['payment_date'] = userCourseData['payment_date'];
          }
          
          await _apiClient.put(
            '/user-courses/$userCourseId/',
            data: updateData,
          );
        }
      } else {
        await _apiClient.post('/listener/courses/$courseId/enroll/');
      }
      
      await loadUserCourses();
      
    } catch (e) {
      _errorMessage = _parseEnrollError(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// данная функция выполняет выход пользователя с курса
  Future<void> leaveCourse(int courseId) async {
    _setLoading(true);
    _clearError();

    try {
      
      final data = await _apiClient.get<Map<String, dynamic>>(
        '/user-courses/',
        queryParams: {'course': courseId.toString()},
      );
      
      
      final results = data['results'] as List? ?? [];
      if (results.isEmpty) {
        throw Exception('Запись на курс не найдена');
      }
      
      final userCourseData = results.first;
      final userCourseId = userCourseData['id'];
      
      
      if (userCourseId == null) {
        throw Exception('Не удалось получить запись на курс');
      }
      
      final updateData = {
        'is_active': false,
        'user': userCourseData['user'],
        'course': userCourseData['course'],
        'registration_date': userCourseData['registration_date'],
        'status_course': userCourseData['status_course'] ?? false,
        'course_price': userCourseData['course_price'],
      };
      
      if (userCourseData['payment_date'] != null) {
        updateData['payment_date'] = userCourseData['payment_date'];
      }
      
      await _apiClient.put(
        '/user-courses/$userCourseId/',
        data: updateData,
      );
      
      await loadUserCourses();
      
      print('Successfully left course');
      
    } catch (e) {
      print('Error leaving course: $e');
      _errorMessage = _parseLeaveError(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// данная функция возвращает ID платежа для курса
  String? getPaymentIdForCourse(int courseId) {
    try {
      final course = _userCourses.firstWhere(
        (course) => course.id == courseId,
        orElse: () => null as Course,
      );
      return course.paymentId;
    } catch (e) {
      return null;
    }
  }

  /// данная функция возвращает дату платежа для курса
  String? getPaymentDateForCourse(int courseId) {
    try {
      final course = _userCourses.firstWhere(
        (course) => course.id == courseId,
        orElse: () => null as Course,
      );
      return course.paymentDate;
    } catch (e) {
      return null;
    }
  }

  /// данная функция возвращает количество активных курсов
  int getActiveCoursesCount() {
    return _userCourses.where((course) => course.isActiveEnrollment == true && course.isCompleted != true).length;
  }

  /// данная функция возвращает количество завершенных курсов
  int getCompletedCoursesCount() {
    return _userCourses.where((course) => course.isCompleted == true).length;
  }

  /// данная функция парсит ошибку записи на курс
  String _parseEnrollError(dynamic e) {
    final errorMessage = e.toString();
    
    if (errorMessage.contains('already enrolled')) {
      return 'Вы уже записаны на этот курс';
    } else if (errorMessage.contains('full') || errorMessage.contains('no places')) {
      return 'Курс заполнен. Нет свободных мест';
    } else if (errorMessage.contains('Unauthorized') || errorMessage.contains('401')) {
      return 'Требуется авторизация';
    } else if (errorMessage.contains('Пользователь на курсе с такими значениями полей') || 
               errorMessage.contains('already exists')) {
      return 'Вы уже записаны на этот курс';
    } else {
      return 'Ошибка записи на курс';
    }
  }

  /// данная функция парсит ошибку выхода с курса
  String _parseLeaveError(dynamic e) {
    final errorMessage = e.toString();
    
    if (errorMessage.contains('not found')) {
      return 'Запись на курс не найдена';
    } else if (errorMessage.contains('already left')) {
      return 'Вы уже покинули этот курс';
    } else {
      return 'Ошибка при выходе из курса';
    }
  }

  /// данная функция очищает данные курсов пользователя
  void clearData() {
    _userCourses = [];
    notifyListeners();
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