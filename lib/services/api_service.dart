import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000';
  static const String apiUrl = '$baseUrl/api';
  
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userEmailKey = 'user_email';
  static const String rememberMeKey = 'remember_me';
  static const String userIdKey = 'user_id';
  
  static Dio _dio = Dio(BaseOptions(
    baseUrl: apiUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  static bool _interceptorSet = false;

  /// Настройка интерсептора
  static Future<void> _setupInterceptor() async {
    if (_interceptorSet) return;
    
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        
        if (options.method.toUpperCase() == 'GET') {
          final path = options.path;
          if (!path.contains('?')) {
            options.path = '$path?format=json';
          } else if (!path.contains('format=json')) {
            options.path = '$path&format=json';
          }
        }
        
        if (options.data != null && options.data is Map) {
          final data = Map<String, dynamic>.from(options.data as Map);
          if (data.containsKey('old_password')) {
            data['old_password'] = '***';
          }
          if (data.containsKey('new_password')) {
            data['new_password'] = '***';
          }
          if (data.containsKey('confirm_password')) {
            data['confirm_password'] = '***';
          }
          if (data.containsKey('password')) {
            data['password'] = '***';
          }
          print('📦 Request data: $data');
        }
        
        return handler.next(options);
      },
      onError: (error, handler) async {

        if (error.response?.statusCode == 401) {
          final path = error.requestOptions.path;
          
          if (path.contains('/auth/token/') ||
              path.contains('/auth/register/') ||
              path.contains('/courses/') ||
              path.contains('/course-categories/') ||
              path.contains('/course-types/') ||
              path.contains('/statistics/')) {
            return handler.next(error);
          }
          
          final refreshed = await refreshToken();
          if (refreshed) {
            final token = await getToken();
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            
            try {
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } catch (e) {
              await clearTokens();
            }
          } else {
            await clearTokens();
          }
        }
        return handler.next(error);
      },
    ));
    
    _interceptorSet = true;
  }

  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(tokenKey);
    } catch (e) {
      return null;
    }
  }

  /// функция получения refresh-токена
  static Future<String?> getRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(refreshTokenKey);
    } catch (e) {
      return null;
    }
  }

  /// функция сохранения токена и данных пользователя
  static Future<void> saveTokens(
    String token, String refreshToken, String email, bool rememberMe) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(tokenKey, token);
      await prefs.setString(refreshTokenKey, refreshToken);
      await prefs.setString(userEmailKey, email);
      await prefs.setBool(rememberMeKey, rememberMe);
    } catch (e) {
      throw Exception(e);
    }
  }

  /// функция сохранения данных пользователя
  static Future<void> saveUserData(Map<String, dynamic> user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (user['id'] != null) {
        await prefs.setInt(userIdKey, user['id']);
      }
    } catch (e) {
      throw Exception(e);
    }
  }

  /// функция очищения всех токенов и данных
  static Future<void> clearTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(tokenKey);
      await prefs.remove(refreshTokenKey);
      await prefs.remove(userEmailKey);
      await prefs.remove(rememberMeKey);
      await prefs.remove(userIdKey);
    } catch (e) {
      throw Exception(e);
    }
  }

  /// функция проверки факта аутентификации пользователя
  static Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// функция получения почты пользователя
  static Future<String?> getUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(userEmailKey);
    } catch (e) {
      return null;
    }
  }

  /// функция проверки сохранения данных (запоминать пользователя или нет)
  static Future<bool> shouldRememberMe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(rememberMeKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// функция обновления токена доступа
  static Future<bool> refreshToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        return false;
      }

      final response = await Dio().post(
        '$apiUrl/auth/token/refresh/',
        data: {'refresh': refreshToken},
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final newToken = data['access'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(tokenKey, newToken);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// данная функция реализует обработку ответов сервера 
  static dynamic _handleResponse(Response response) {

    if (response.statusCode == 200 || response.statusCode == 201) {
      if (response.data is Map<String, dynamic>) {
        return response.data;
      } else if (response.data is List) {
        return {'data': response.data};
      } else if (response.data is String) {
        final str = response.data as String;
        if (str.contains('<!DOCTYPE html>') || str.contains('<html') || str.contains('Page not found')) {
          throw Exception('Сервер вернул HTML-страницу вместо JSON (возможно 404/403/500)');
        }
        return {'message': str};
      } else {
        return {'data': response.data};
      }
    } else if (response.statusCode == 404) {
      throw Exception('Запрашиваемый ресурс не найден (404)');
    } else if (response.statusCode == 403) {
      throw Exception('Доступ запрещён (403)');
    } else if (response.statusCode == 401) {
      throw Exception('Требуется авторизация (401)');
    } else {
      throw Exception('Ошибка сервера: ${response.statusCode}');
    }
  }

  /// функция аутентификации пользователя 
  static Future<Map<String, dynamic>> login(
    String username, String password) async {
    
    try {
      final dioForLogin = Dio(BaseOptions(
        baseUrl: apiUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ));
      
      final response = await dioForLogin.post('/auth/token/', data: {
        'username': username,
        'password': password,
      });

      final data = _handleResponse(response);
      final accessToken = data['access'];
      final refreshToken = data['refresh'];

      if (accessToken != null && refreshToken != null) {
        await saveTokens(accessToken, refreshToken, username, true);
        _interceptorSet = false;
      }

      return data;
    } on DioException catch (e) {
      throw Exception(_parseAuthError(e, 'Ошибка авторизации'));
    }
  }

  /// функция регистрации нового пользователя
  static Future<Map<String, dynamic>> register(
    String email,
    String password,
    String firstName,
    String lastName,
    String username) async {
    
    try {
      final dioForRegister = Dio(BaseOptions(
        baseUrl: apiUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ));
      
      final response = await dioForRegister.post('/auth/register/', data: {
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'username': username,
        'confirm_password': password,
      });

      final data = _handleResponse(response);
      
      if (data.containsKey('access') && data.containsKey('refresh')) {
        await saveTokens(
          data['access'],
          data['refresh'],
          email,
          true,
        );
        _interceptorSet = false;
      }

      return data;
    } on DioException catch (e) {
      throw Exception(_parseAuthError(e, 'Ошибка регистрации'));
    }
  }

  /// функция получения текущего пользователя
  static Future<Map<String, dynamic>> getCurrentUser() async {
    await _setupInterceptor();
    
    try {
      final response = await _dio.get('/users/me/');
      final data = _handleResponse(response);
      await saveUserData(data);
      return data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await clearTokens();
      }
      throw Exception('Ошибка загрузки пользователя');
    }
  }

  /// функция получения статистики платформы
  static Future<Map<String, dynamic>> getStatistics() async {
    try {
      await _setupInterceptor();
      
      final response = await _dio.get('/statistics/');
      return _handleResponse(response);
      
    } on DioException catch (e) {
      print('Error fetching statistics: $e');
      print('Response data: ${e.response?.data}');
      
      return {
        'total_users': 0,
        'total_courses': 0,
        'total_enrollments': 0,
        'total_certificates': 0,
        'active_users': 0,
        'average_rating': 0.0,
      };
    } catch (e) {
      print('Unexpected error fetching statistics: $e');
      return {
        'total_users': 0,
        'total_courses': 0,
        'total_enrollments': 0,
        'total_certificates': 0,
        'active_users': 0,
        'average_rating': 0.0,
      };
    }
  }

  /// функция получения курсов пользователя
  static Future<List<dynamic>> getUserCourses() async {
    try {
      await _setupInterceptor();
      final response = await _dio.get('/user-courses/');
      final data = _handleResponse(response);
      return data['results'] ?? [];
    } on DioException {
      return [];
    }
  }

  /// функция получения прогресса слушателя 
  static Future<Map<String, dynamic>> getListenerProgress() async {
    await _setupInterceptor();
    
    try {
      final response = await _dio.get('/listener/progress/');
      return _handleResponse(response);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return {'courses': []};
      }
      rethrow;
    }
  }

  /// функция получения материалов курса
  static Future<Map<String, dynamic>> getCourseMaterials(int courseId) async {
    await _setupInterceptor();
    
    try {
      final response = await _dio.get('/listener/progress/$courseId/materials/');
      return _handleResponse(response);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return {
          'course': {'id': courseId},
          'materials_by_lecture': [],
          'total_progress': 0,
        };
      }
      rethrow;
    }
  }

  /// функция получения результатов и сертификатов слушателя
  static Future<Map<String, dynamic>> getListenerResults() async {
    await _setupInterceptor();
    
    try {
      final response = await _dio.get('/listener/results/');
      return _handleResponse(response);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return {
          'statistics': {},
          'courses_stats': [],
          'certificates': [],
        };
      }
      rethrow;
    }
  }

  /// функция получения курсов с фильтрами
  static Future<List<dynamic>> getCoursesWithFilters({
    String? searchQuery,
    List<int>? categoryIds,
    List<int>? typeIds,
    bool? hasCertificate,
    bool? freeOnly,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final dio = Dio();
      
      final Map<String, dynamic> queryParams = {
        'format': 'json',
      };
      
      if (searchQuery != null && searchQuery.isNotEmpty) {
        queryParams['search'] = searchQuery;
      }
      
      if (categoryIds != null && categoryIds.isNotEmpty) {
        queryParams['course_category'] = categoryIds.join(',');
      }
      
      if (typeIds != null && typeIds.isNotEmpty) {
        queryParams['course_type'] = typeIds.join(',');
      }
      
      if (hasCertificate != null) {
        queryParams['has_certificate'] = hasCertificate.toString();
      }
      
      if (freeOnly != null && freeOnly) {
        queryParams['free_only'] = 'true';
      }
      
      if (sortBy != null && sortBy.isNotEmpty) {
        queryParams['sort_by'] = sortBy;
        
        if (sortOrder != null && sortOrder.isNotEmpty) {
          queryParams['sort_order'] = sortOrder.toLowerCase();
        } else {
          queryParams['sort_order'] = 'asc';
        }
      }
      
      final response = await dio.get(
        '$apiUrl/courses/',
        queryParameters: queryParams,
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );
      
      final data = _handleResponse(response);
      final List<dynamic> courses = List<dynamic>.from(data['results'] ?? []);
      return courses;
      
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          throw Exception('Требуется авторизация');
        } else if (e.response?.statusCode == 400) {
          throw Exception('Неверные параметры запроса');
        }
      }
      throw Exception('Ошибка загрузки курсов: $e');
    }
  }

  /// функция получения категорий курсов
  static Future<List<dynamic>> getCourseCategories() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        '$apiUrl/course-categories/',
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );
      
      final data = _handleResponse(response);
      return data['results'] ?? [];
    } on DioException {
      return [];
    }
  }

  /// функция получения типов курсов
  static Future<List<dynamic>> getCourseTypes() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        '$apiUrl/course-types/',
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );
      
      final data = _handleResponse(response);
      return data['results'] ?? [];
    } on DioException {
      return [];
    }
  }

  /// функция записи на курс
  static Future<Map<String, dynamic>> enrollToCourse(int courseId) async {
    await _setupInterceptor();
    
    try {
      final response = await _dio.post('/listener/courses/$courseId/enroll/');
      return _handleResponse(response);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await clearTokens();
      }
      
      throw Exception(_parseEnrollError(e));
    }
  }

  /// функция выхода из аккаунта
  static Future<void> logout() async {
    try {
      final refreshToken = await getRefreshToken();
      
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _dio.post(
          '$apiUrl/auth/logout/',
          data: {'refresh': refreshToken},
          options: Options(
            headers: {
              'Content-Type': 'application/json',
            },
          ),
        );
      } else {
        print('No refresh token found, skipping server logout');
      }
    } catch (e) {
      print('Logout error (server): $e');
    } finally {
      await clearTokens();
    }
  }

  /// функция получения url изображения
  static String getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return '';
    }
    
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    
    if (imagePath.startsWith('/media/')) {
      return '$baseUrl$imagePath';
    }

    if (imagePath.startsWith('course_photos/') || 
        imagePath.startsWith('lecture_documents/') ||
        imagePath.startsWith('assignment_files/')) {
      return '$baseUrl/media/$imagePath';
    }
    
    return '$baseUrl/media/$imagePath';
  }
  
  /// функция получения id пользователя
  static Future<int?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(userIdKey);
    } catch (e) {
      return null;
    }
  }

  /// функция проверки соединения
  static Future<bool> checkConnection() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        '$apiUrl/',
        options: Options(
          headers: {'Accept': 'application/json'},
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// функция обновления данных профиля пользователя
  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    await _setupInterceptor();
    
    try {
      final response = await _dio.put('/users/update_profile/', data: data);
      return _handleResponse(response);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await clearTokens();
      }
      
      throw Exception(_parseProfileError(e));
    }
  }

  /// функция смены пароля
  static Future<Map<String, dynamic>> changePassword(
    String oldPassword, 
    String newPassword
  ) async {
    await _setupInterceptor();
    
    try {
      final requestBody = {
        'old_password': oldPassword,
        'new_password': newPassword,
        'confirm_password': newPassword,
      };
      
      final response = await _dio.post(
        '/users/change_password/',
        data: requestBody,
      );
      
      return _handleResponse(response);
      
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await clearTokens();
        throw Exception('Требуется авторизация. Пожалуйста, войдите снова.');
      }
      
      throw Exception(_parsePasswordError(e));
    } catch (e) {
      throw Exception('Неожиданная ошибка при смене пароля');
    }
  }

  /// данная функция реализует создания платежа
  static Future<Map<String, dynamic>> createPayment(int courseId) async {
    await _setupInterceptor();
    
    try {
      final response = await _dio.post('/payments/create/$courseId/');
      return _handleResponse(response);
    } on DioException catch (e) {
      print('создание платежа: ${e.response?.data}');
      if (e.response?.statusCode == 400) {
        final errorData = e.response?.data;
        if (errorData != null && errorData is Map && errorData.containsKey('detail')) {
          throw Exception(errorData['detail']);
        }
      }
      if (e.response?.statusCode == 500) {
        throw Exception('Ошибка сервера при создании платежа. Проверьте настройки ЮКассы.');
      }
      throw Exception('Ошибка создания платежа');
    } catch (e) {
      print('ошибка создания платежа: $e');
      throw Exception('Ошибка создания платежа: $e');
    }
  }

  /// данная функция реализует проверку статуса платежа
  static Future<Map<String, dynamic>> checkPaymentStatus(String paymentId) async {
    await _setupInterceptor();
    
    try {
      final response = await _dio.get('/payments/status/$paymentId/');
      return _handleResponse(response);
    } on DioException catch (e) {
      print('Check payment status error: ${e.response?.data}');
      throw Exception('Ошибка проверки статуса платежа');
    } catch (e) {
      print('Check payment error: $e');
      throw Exception('Ошибка проверки статуса платежа: $e');
    }
  }

  /// данная функция реализует подтверждение платежа
  static Future<Map<String, dynamic>> confirmPayment(String paymentId) async {
    await _setupInterceptor();
    
    try {
      final response = await _dio.post('/payments/confirm/$paymentId/');
      return _handleResponse(response);
    } on DioException catch (e) {
      print('Confirm payment error: ${e.response?.data}');
      if (e.response?.statusCode == 400) {
        final errorData = e.response?.data;
        if (errorData != null && errorData is Map && errorData.containsKey('detail')) {
          throw Exception(errorData['detail']);
        }
      }
      throw Exception('Ошибка подтверждения платежа');
    } catch (e) {
      print('Confirm payment error: $e');
      throw Exception('Ошибка подтверждения платежа: $e');
    }
  }

  /// данная функция реализует получение чека
  static Future<Map<String, dynamic>> getReceipt(String paymentId) async {
    await _setupInterceptor();
    
    try {
      final response = await _dio.get('/payments/receipt/$paymentId/');
      return _handleResponse(response);
    } on DioException catch (e) {
      print('Get receipt error: ${e.response?.data}');
      throw Exception('Ошибка получения чека');
    } catch (e) {
      print('Get receipt error: $e');
      throw Exception('Ошибка получения чека: $e');
    }
  }
  
  /// данная функция реализует получение прогресс завершения курса
  static Future<Map<String, dynamic>> getCourseCompletion(int courseId) async {
    await _setupInterceptor();
    
    try {
      final response = await _dio.get('/courses/$courseId/completion/');
      return _handleResponse(response);
    } on DioException catch (e) {
      print('Get course completion error: ${e.response?.data}');
      return {'completion': 0.0};
    } catch (e) {
      print('Get course completion error: $e');
      return {'completion': 0.0};
    }
  }

  static String _parseAuthError(DioException e, String defaultMessage) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        if (data.containsKey('detail')) return data['detail'].toString();
      } else if (data is String) {
        return data;
      }
    } catch (_) {}
    return defaultMessage;
  }

  static String _parseEnrollError(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        if (data.containsKey('detail')) return data['detail'].toString();
        if (data.containsKey('error')) return data['error'].toString();
        if (data.containsKey('message')) return data['message'].toString();
      } else if (data is String) {
        return data;
      }
    } catch (_) {}
    return 'Ошибка записи на курс';
  }

  static String _parseProfileError(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        if (data.containsKey('detail')) return data['detail'].toString();

        final errors = <String>[];
        data.forEach((key, value) {
          if (value is List) {
            errors.add('$key: ${value.join(', ')}');
          } else if (value != null) {
            errors.add('$key: $value');
          }
        });
        if (errors.isNotEmpty) return errors.join('; ');
      }
    } catch (_) {}
    return 'Ошибка обновления профиля';
  }

  static String _parsePasswordError(DioException e) {
    if (e.response?.data != null) {
      final data = e.response!.data;
      
      if (data is Map) {
        if (data.containsKey('old_password')) {
          final errors = data['old_password'];
          if (errors is List && errors.isNotEmpty) {
            final error = errors.first.toString();
            return 'Неверный старый пароль: $error';
          }
          return 'Неверный старый пароль';
        }
        
        if (data.containsKey('detail')) {
          return data['detail'].toString();
        }
        
        if (data.containsKey('new_password')) {
          final errors = data['new_password'];
          if (errors is List && errors.isNotEmpty) {
            final error = errors.first.toString().toLowerCase();
            
            if (error.contains('too short')) {
              return 'Пароль слишком короткий. Минимум 8 символов';
            }
            if (error.contains('too common')) {
              return 'Пароль слишком простой. Используйте более сложный пароль';
            }
            if (error.contains('too similar')) {
              return 'Пароль слишком похож на ваши другие данные';
            }
            if (error.contains('entirely numeric')) {
              return 'Пароль не должен состоять только из цифр';
            }
            
            return 'Новый пароль: ${errors.first}';
          }
        }
        
        final errors = <String>[];
        data.forEach((key, value) {
          if (value is List && value.isNotEmpty) {
            final fieldName = _getFieldName(key);
            errors.add('$fieldName: ${value.first}');
          } else if (value != null) {
            final fieldName = _getFieldName(key);
            errors.add('$fieldName: $value');
          }
        });
        
        if (errors.isNotEmpty) {
          return errors.join('; ');
        }
      } 
      else if (data is String) {
        return data;
      }
    }
    
    if (e.response?.statusCode == 400) {
      return 'Некорректные данные. Проверьте введенные значения';
    }
    if (e.response?.statusCode == 403) {
      return 'Доступ запрещен. У вас нет прав для смены пароля';
    }
    if (e.response?.statusCode == 404) {
      return 'Сервис смены пароля временно недоступен';
    }
    
    return 'Ошибка смены пароля (${e.response?.statusCode ?? 'нет ответа'})';
  }

  static String _getFieldName(String field) {
    final Map<String, String> fieldNames = {
      'old_password': 'Старый пароль',
      'new_password': 'Новый пароль',
      'confirm_password': 'Подтверждение пароля',
      'non_field_errors': 'Общие ошибки',
    };
    
    return fieldNames[field] ?? field.replaceAll('_', ' ');
  }

/// данная функция получает детали задания
static Future<Map<String, dynamic>> getAssignmentDetail(int courseId, int assignmentId) async {
  await _setupInterceptor();
  
  try {
    final response = await _dio.get(
      '/listener/progress/$courseId/assignments/$assignmentId/',
    );
    return _handleResponse(response);
  } on DioException catch (e) {
    if (e.response?.statusCode == 401) {
      await clearTokens();
    }
    throw Exception('Ошибка загрузки деталей задания');
  } catch (e) {
    throw Exception('Не удалось загрузить задание: $e');
  }
}
  

  /// данная функция отправляет практическую работу
static Future<Map<String, dynamic>> submitPracticalAssignment(
    int courseId,
    int assignmentId,
    String comment,
    List<MultipartFile> files,
  ) async {
  await _setupInterceptor();
  try {
    final formData = FormData.fromMap({
      'practical_assignment': assignmentId.toString(),
      'comment': comment.trim(),
      'files': files,
    });

    final response = await _dio.post(
      '/listener/progress/$courseId/assignments/$assignmentId/submit/',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    return _handleResponse(response);
  } on DioException catch (e) {
    if (e.response?.statusCode == 401) {
      await clearTokens();
    }
    throw Exception('Ошибка отправки работы');
  } catch (e) {
    throw Exception('Не удалось отправить задание: $e');
  }
}

  /// запрос на восстановление пароля
static Future<Map<String, dynamic>> requestPasswordReset(String email) async {
  try {
    final response = await Dio().post(
      '$apiUrl/auth/password-reset/request/',
      data: {'email': email},
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    
    return _handleResponse(response);
  } on DioException catch (e) {
    throw Exception(_parsePasswordResetError(e));
  }
}

/// верификация кода восстановления
static Future<Map<String, dynamic>> verifyPasswordResetCode(String email, String code) async {
  try {
    final response = await Dio().post(
      '$apiUrl/auth/password-reset/verify/',
      data: {'email': email, 'code': code},
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    
    return _handleResponse(response);
  } on DioException catch (e) {
    throw Exception(_parsePasswordResetError(e));
  }
}

/// сброс пароля с новым паролем
static Future<Map<String, dynamic>> resetPassword(String email, String code, String newPassword) async {
  try {
    final response = await Dio().post(
      '$apiUrl/auth/password-reset/confirm/',
      data: {
        'email': email,
        'code': code,
        'new_password': newPassword,
        'confirm_password': newPassword,
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    
    return _handleResponse(response);
  } on DioException catch (e) {
    throw Exception(_parsePasswordResetError(e));
  }
}

/// парсинг ошибок восстановления пароля
static String _parsePasswordResetError(DioException e) {
  if (e.response?.data != null) {
    final data = e.response!.data;
    
    if (data is Map) {
      if (data.containsKey('email')) {
        final errors = data['email'];
        if (errors is List && errors.isNotEmpty) {
          return errors.first.toString();
        }
      }
      
      if (data.containsKey('code')) {
        final errors = data['code'];
        if (errors is List && errors.isNotEmpty) {
          return errors.first.toString();
        }
      }
      
      if (data.containsKey('new_password')) {
        final errors = data['new_password'];
        if (errors is List && errors.isNotEmpty) {
          final error = errors.first.toString().toLowerCase();
          
          if (error.contains('too short')) {
            return 'Пароль слишком короткий. Минимум 8 символов';
          }
          if (error.contains('too common')) {
            return 'Пароль слишком простой. Используйте более сложный пароль';
          }
          if (error.contains('too similar')) {
            return 'Пароль слишком похож на ваши другие данные';
          }
          if (error.contains('entirely numeric')) {
            return 'Пароль не должен состоять только из цифр';
          }
          
          return 'Пароль: ${errors.first}';
        }
      }
      
      if (data.containsKey('confirm_password')) {
        final errors = data['confirm_password'];
        if (errors is List && errors.isNotEmpty) {
          return 'Пароли не совпадают';
        }
      }
      
      if (data.containsKey('detail')) {
        return data['detail'].toString();
      }
      
      if (data.containsKey('error')) {
        return data['error'].toString();
      }
      
      final errors = <String>[];
      data.forEach((key, value) {
        if (value is List && value.isNotEmpty) {
          errors.add('${_getFieldName(key)}: ${value.first}');
        } else if (value != null) {
          errors.add('${_getFieldName(key)}: $value');
        }
      });
      
      if (errors.isNotEmpty) {
        return errors.join('; ');
      }
    } 
    else if (data is String) {
      return data;
    }
  }
  
  if (e.response?.statusCode == 400) {
    return 'Неверные данные. Проверьте введенные значения';
  }
  if (e.response?.statusCode == 404) {
    return 'Сервис восстановления пароля временно недоступен';
  }
  
  return 'Ошибка восстановления пароля (${e.response?.statusCode ?? 'нет ответа'})';
}


/// данная функция получает все попытки сдачи задания с обратной связью
static Future<Map<String, dynamic>> getAssignmentAttempts(int courseId, int assignmentId) async {
  await _setupInterceptor();
  
  try {
    final response = await _dio.get(
      '/listener/progress/$courseId/assignments/$assignmentId/attempts/',
    );
    return _handleResponse(response);
  } on DioException catch (e) {
    if (e.response?.statusCode == 401) {
      await clearTokens();
    }
    throw Exception('Ошибка загрузки попыток сдачи');
  } catch (e) {
    throw Exception('Не удалось загрузить попытки: $e');
  }
}

/// данная функция редактирует попытку сдачи задания
static Future<Map<String, dynamic>> updateAssignmentAttempt(
    int courseId, 
    int assignmentId,
    int attemptId,
    String comment,
    List<int> filesToRemove,
    List<MultipartFile> newFiles,
  ) async {
  await _setupInterceptor();
  
  try {
    final formData = FormData.fromMap({
      'comment': comment,
      'files_to_remove': filesToRemove.join(','),
    });
    
    for (var file in newFiles) {
      formData.files.add(MapEntry('files', file));
    }
    
    final response = await _dio.put(
      '/listener/progress/$courseId/assignments/$assignmentId/attempt/$attemptId/',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    
    return _handleResponse(response);
  } on DioException catch (e) {
    if (e.response?.statusCode == 401) {
      await clearTokens();
    }
    throw Exception('Ошибка обновления попытки');
  } catch (e) {
    throw Exception('Не удалось обновить попытку: $e');
  }
}

/// сохранение файла в локальное хранилище
static Future<String> saveFile(List<int> bytes, String fileName) async {
  try {

    Directory? directory;
    
    if (Platform.isAndroid) {
      directory = await getDownloadsDirectory();
    } else if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
    } else if (Platform.isWindows) {
      directory = await getDownloadsDirectory();
      if (directory == null) {
        directory = await getApplicationDocumentsDirectory();
      }
    } else {
      directory = await getTemporaryDirectory();
    }

    if (directory == null) {
      throw Exception('Не удалось получить директорию для сохранения');
    }

    final certDir = Directory('${directory.path}/Unireax/Certificates');
    if (!await certDir.exists()) {
      await certDir.create(recursive: true);
    }

    final filePath = '${certDir.path}/$fileName';
    final file = File(filePath);

    await file.writeAsBytes(bytes);
    
    print('Файл сохранен: $filePath');
    
    return filePath;
  } catch (e) {
    print('Ошибка сохранения файла: $e');
    throw Exception('Ошибка сохранения файла: $e');
  }
}

}