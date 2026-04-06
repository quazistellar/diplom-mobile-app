import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../services/api_client.dart';
import '../models/progress.dart';
import '../models/assignment_attempt.dart';
import '../models/test.dart';
import '../models/certificate.dart';

class ProgressProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  
  bool _isLoading = false;
  String? _errorMessage;
  
  List<CourseProgress> _enrolledCourses = [];
  List<LectureWithMaterials> _courseMaterials = [];
  StatisticsSummary? _courseStats;
  List<CertificateWithCourse> _certificates = [];
  
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<CourseProgress> get enrolledCourses => _enrolledCourses;
  List<LectureWithMaterials> get courseMaterials => _courseMaterials;
  StatisticsSummary? get courseStats => _courseStats;
  List<CertificateWithCourse> get certificates => _certificates;
  
  /// данная функция логирует сообщения
  void _log(String message) {
    if (kDebugMode) print('[ProgressProvider] $message');
  }
  
  /// данная функция загружает курсы с прогрессом пользователя
  Future<void> loadEnrolledCourses() async {
    _setLoading(true);
    _clearError();
    
    try {
      if (!await _apiClient.isAuthenticated()) {
        throw const ApiException(message: 'Требуется авторизация');
      }
      
      _log('Загружаем курсы с прогрессом...');
      
      final data = await _apiClient.get<List>('/listener/progress/');
      
      _enrolledCourses = data
          .map((json) => CourseProgress.fromJson(json))
          .toList();
      
      _log('Получено ${_enrolledCourses.length} курсов');
      
    } catch (e) {
      _errorMessage = e.toString();
      _enrolledCourses = [];
      _log('Ошибка загрузки курсов: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  /// данная функция загружает материалы курса
  Future<void> loadCourseMaterials(int courseId) async {
    _setLoading(true);
    _clearError();
    
    try {
      if (!await _apiClient.isAuthenticated()) {
        throw const ApiException(message: 'Требуется авторизация');
      }
      
      _log('Загружаем материалы курса $courseId...');
      
      final data = await _apiClient.get<Map<String, dynamic>>(
        '/listener/progress/$courseId/materials/'
      );
      
      final materials = data['materials_by_lecture'] as List? ?? [];
      _courseMaterials = materials
          .map((json) => LectureWithMaterials.fromJson(json))
          .toList();
      
      _log('Получено ${_courseMaterials.length} лекций с материалами');
      
    } catch (e) {
      _errorMessage = e.toString();
      _courseMaterials = [];
      _log('Ошибка загрузки материалов: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  /// данная функция загружает детали лекции
  Future<Map<String, dynamic>> loadLectureDetails(int courseId, int lectureId) async {
    try {
      if (!await _apiClient.isAuthenticated()) {
        throw const ApiException(message: 'Требуется авторизация');
      }
      
      _log('Загружаем детали лекции $lectureId...');
      
      return await _apiClient.get(
        '/listener/progress/$courseId/lectures/$lectureId/'
      );
    } catch (e) {
      _log('Ошибка загрузки лекции: $e');
      rethrow;
    }
  }
  
  /// данная функция загружает детали задания
  Future<AssignmentDetail> loadAssignmentDetails(int courseId, int assignmentId) async {
    try {
      if (!await _apiClient.isAuthenticated()) {
        throw const ApiException(message: 'Требуется авторизация');
      }
      
      _log('Загружаем детали задания $assignmentId...');
      
      final data = await _apiClient.get<Map<String, dynamic>>(
        '/listener/progress/$courseId/assignments/$assignmentId/'
      );
      
      return AssignmentDetail.fromJson(data);
    } catch (e) {
      _log('Ошибка загрузки задания: $e');
      rethrow;
    }
  }
  
  /// данная функция отправляет задание на проверку
  Future<Map<String, dynamic>> submitAssignment(
    int courseId, 
    int assignmentId, 
    String comment, 
    List<Map<String, dynamic>> files,
  ) async {
    try {
      if (!await _apiClient.isAuthenticated()) {
        throw const ApiException(message: 'Требуется авторизация');
      }
      
      _log('Отправляем задание $assignmentId...');
      
      final formData = FormData();
      formData.fields.add(MapEntry('comment', comment));
      formData.fields.add(MapEntry('practical_assignment', assignmentId.toString()));
      
      for (var file in files) {
        formData.files.add(MapEntry(
          'files',
          MultipartFile.fromFileSync(
            file['path'],
            filename: file['name'],
          ),
        ));
      }
      
      _log('Отправляем ${files.length} файлов...');
      
      return await _apiClient.post(
        '/listener/progress/$courseId/assignments/$assignmentId/submit/',
        data: formData,
        isFormData: true,
      );
    } catch (e) {
      _log('Ошибка отправки задания: $e');
      rethrow;
    }
  }
  
  /// данная функция обновляет попытку выполнения задания
  Future<Map<String, dynamic>> updateAssignmentAttempt(
    int courseId, 
    int assignmentId,
    int attemptId,
    String comment,
    List<int> filesToRemove,
    List<Map<String, dynamic>> newFiles,
  ) async {
    try {
      if (!await _apiClient.isAuthenticated()) {
        throw const ApiException(message: 'Требуется авторизация');
      }
      
      _log('Обновляем попытку $attemptId...');
      
      final formData = FormData.fromMap({
        'comment': comment,
        'files_to_remove': filesToRemove.join(','),
      });
      
      for (var file in newFiles) {
        formData.files.add(MapEntry(
          'files',
          MultipartFile.fromFileSync(
            file['path'],
            filename: file['name'],
          ),
        ));
      }
      
      return await _apiClient.put(
        '/listener/progress/$courseId/assignments/$assignmentId/attempt/$attemptId/',
        data: formData,
        isFormData: true,
      );
    } catch (e) {
      _log('Ошибка обновления попытки: $e');
      rethrow;
    }
  }
  
  /// данная функция загружает попытки выполнения задания
  Future<Map<String, dynamic>> getAssignmentAttempts(int courseId, int assignmentId) async {
    try {
      if (!await _apiClient.isAuthenticated()) {
        throw const ApiException(message: 'Требуется авторизация');
      }
      
      return await _apiClient.get(
        '/listener/progress/$courseId/assignments/$assignmentId/attempts/'
      );
    } catch (e) {
      _log('Ошибка загрузки попыток: $e');
      rethrow;
    }
  }
  
  /// данная функция загружает тест
  Future<Map<String, dynamic>> getTest(int courseId, int testId) async {
    try {
      if (!await _apiClient.isAuthenticated()) {
        throw const ApiException(message: 'Требуется авторизация');
      }
      
      _log('Загружаем тест $testId...');
      
      final url = '/listener/courses/$courseId/tests/$testId/';
      return await _apiClient.get<Map<String, dynamic>>(url);
      
    } catch (e) {
      _log('Ошибка загрузки теста: $e');
      rethrow;
    }
  }

  /// данная функция отправляет ответы на тест
  Future<Map<String, dynamic>> submitTest(
    int courseId, 
    int testId, 
    List<Map<String, dynamic>> answers,
    int timeSpent,
  ) async {
    try {
      if (!await _apiClient.isAuthenticated()) {
        throw const ApiException(message: 'Требуется авторизация');
      }
      
      _log('Отправляем тест $testId...');
      _log('Ответов: ${answers.length}, время: ${timeSpent}с');
      
      final url = '/listener/courses/$courseId/tests/$testId/';
      
      final requestData = {
        'answers': answers,
        'time_spent': timeSpent,
      };
      
      return await _apiClient.post(
        url,
        data: json.encode(requestData),
      );
      
    } catch (e) {
      _log('Ошибка отправки теста: $e');
      rethrow;
    }
  }

  /// данная функция загружает детали результата теста
  Future<Map<String, dynamic>> getTestResultDetails(int testResultId) async {
    try {
      final token = await _apiClient.getToken();
      if (token == null) {
        throw Exception('Требуется авторизация');
      }
      
      _log('Загружаем детали результата теста $testResultId...');
      
      final dio = Dio();
      final response = await dio.get(
        '${ApiClient.apiUrl}/listener/test-results/$testResultId/',
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );
      
      _log('Детали результата загружены');
      return response.data;
      
    } on DioException catch (e) {
      _log('Ошибка загрузки деталей результата: ${e}');
      throw Exception('Ошибка загрузки деталей результата: ${e}');
    }
  }
  
  /// данная функция загружает попытки прохождения теста
  Future<Map<String, dynamic>> getTestAttempts(int courseId, int testId) async {
    try {
      if (!await _apiClient.isAuthenticated()) {
        throw const ApiException(message: 'Требуется авторизация');
      }
      
      _log('Загружаем попытки теста $testId...');
      
      return await _apiClient.get(
        '/listener/courses/$courseId/tests/$testId/attempts/'
      );
      
    } catch (e) {
      _log('Ошибка загрузки попыток: $e');
      rethrow;
    }
  }
  
  /// данная функция загружает результаты и сертификаты
  Future<void> loadResults() async {
    _setLoading(true);
    _clearError();
    
    try {
      if (!await _apiClient.isAuthenticated()) {
        throw const ApiException(message: 'Требуется авторизация');
      }
      
      _log('Загружаем результаты и сертификаты...');
      
      final data = await _apiClient.get<Map<String, dynamic>>('/listener/results/');
      _courseStats = StatisticsSummary.fromJson(data);
      _certificates = (data['certificates'] as List? ?? [])
          .map((json) => CertificateWithCourse.fromJson(json))
          .toList();
      
      _log('Загружено сертификатов: ${_certificates.length}');
      
    } catch (e) {
      _errorMessage = e.toString();
      _certificates = [];
      _courseStats = null;
      _log('Ошибка загрузки результатов: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  /// данная функция очищает сообщение об ошибке
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  /// данная функция очищает данные прогресса
  void clearData() {
    _enrolledCourses = [];
    _courseMaterials = [];
    _courseStats = null;
    _certificates = [];
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