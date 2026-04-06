import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// данный класс предоставляет клиент для работы с API
class ApiClient {
  // Единый URL вашего сайта на Amvera
  static const String _baseUrl = 'https://unireax-moonkid.amvera.io';
  
  /// данная функция возвращает базовый URL
  static String get baseUrl => _baseUrl;
  
  /// данная функция возвращает полный URL API
  static String get apiUrl => '$baseUrl/api';

  // Остальные константы
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userEmailKey = 'user_email';
  static const String rememberMeKey = 'remember_me';
  static const String userIdKey = 'user_id';
  static const String remainingAttemptsKey = 'remaining_attempts';
  static const String blockEndTimeKey = 'block_end_time';

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  late Dio _dio;
  bool _interceptorSet = false;

  /// данная функция возвращает экземпляр Dio с токеном
  Future<Dio> get dio async {
    await _ensureInitialized();
    return _dio;
  }

  /// данная функция возвращает публичный экземпляр Dio без токена
  Future<Dio> get publicDio async {
    return Dio(BaseOptions(
      baseUrl: apiUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
  }

  /// функция проверки доступности URL (упрощённая, так как URL один)
  static Future<void> checkDeviceUrl() async {
    // Теперь не нужно проверять несколько URL, просто проверяем доступность сервера
    try {
      final testUrl = '$apiUrl/auth/token/';
      final response = await http.get(
        Uri.parse(testUrl),
      ).timeout(const Duration(seconds: 5));
      print('Сервер доступен: ${response.statusCode}');
    } catch (e) {
      print('Сервер недоступен: $e');
    }
  }

  /// данная функция инициализирует Dio и настраивает перехватчик
  Future<void> _ensureInitialized() async {
    if (!_interceptorSet) {
      _dio = Dio(BaseOptions(
        baseUrl: apiUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ));
      _setupInterceptor();
    }
  }

  /// данная функция настраивает перехватчик запросов
  void _setupInterceptor() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        print('Error ${error.response?.statusCode}: ${error.requestOptions.path}');
        
        final publicEndpoints = [
          '/auth/token/',
          '/auth/register/',
          '/auth/token/refresh/',
          '/auth/password-reset/',
          '/auth/login/status/',
          '/courses/',
          '/course-categories/',
          '/course-types/',
        ];
        
        final path = error.requestOptions.path;
        final isPublicEndpoint = publicEndpoints.any((endpoint) => path.contains(endpoint));
        
        if (error.response?.statusCode == 401 && !isPublicEndpoint) {
          print('Attempting to refresh token...');
          final refreshed = await refreshToken();
          
          if (refreshed) {
            print('Token refreshed, retrying request...');
            final token = await getToken();
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            
            try {
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } catch (e) {
              print('Retry failed: $e');
            }
          } else {
            print('Token refresh failed');
          }
        }
        
        return handler.next(error);
      },
    ));
    _interceptorSet = true;
  }

  /// данная функция возвращает сохраненный токен
  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(tokenKey);
    } catch (e) {
      return null;
    }
  }

  /// данная функция возвращает сохраненный refresh токен
  Future<String?> getRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(refreshTokenKey);
    } catch (e) {
      return null;
    }
  }

  /// данная функция сохраняет токены и данные пользователя
  Future<void> saveTokens(String token, String refreshToken, String email, bool rememberMe) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(tokenKey, token);
      await prefs.setString(refreshTokenKey, refreshToken);
      await prefs.setString(userEmailKey, email);
      await prefs.setBool(rememberMeKey, rememberMe);
    } catch (e) {
      throw Exception('Ошибка сохранения токенов: $e');
    }
  }

  /// данная функция сохраняет ID пользователя
  Future<void> saveUserId(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(userIdKey, userId);
    } catch (e) {
      throw Exception('Ошибка сохранения ID пользователя: $e');
    }
  }

  /// данная функция очищает все сохраненные токены
  Future<void> clearTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(tokenKey);
      await prefs.remove(refreshTokenKey);
      await prefs.remove(userEmailKey);
      await prefs.remove(rememberMeKey);
      await prefs.remove(userIdKey);
      await prefs.remove(remainingAttemptsKey);
      await prefs.remove(blockEndTimeKey);
    } catch (e) {
      throw Exception('Ошибка очистки токенов: $e');
    }
  }

  /// данная функция проверяет авторизацию пользователя
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// данная функция возвращает email пользователя
  Future<String?> getUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(userEmailKey);
    } catch (e) {
      return null;
    }
  }

  /// данная функция возвращает ID пользователя
  Future<int?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(userIdKey);
    } catch (e) {
      return null;
    }
  }

  /// данная функция обновляет токен доступа
  Future<bool> refreshToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) return false;

      final response = await Dio().post(
        '$apiUrl/auth/token/refresh/',
        data: {'refresh': refreshToken},
      );

      if (response.statusCode == 200) {
        final newToken = response.data['access'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(tokenKey, newToken);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// проверка статуса блокировки
  Future<Map<String, dynamic>> checkLoginStatus(String username) async {
    try {
      print('🔍 ApiClient.checkLoginStatus: запрос для username: $username');
      final client = await publicDio;
      
      final response = await client.get(
        '/api/login/status/', 
        queryParameters: {'username': username}
      );

      return {
        'blocked': response.data['blocked'] ?? false,
        'remainingAttempts': response.data['remaining_attempts'] ?? 5,
        'minutesLeft': response.data['minutes_left'] ?? 0,
        'maxAttempts': response.data['max_attempts'] ?? 5,
      };
    } catch (e) {
      if (e is DioException) {
        print('   Статус: ${e.response?.statusCode}');
        print('   Данные: ${e.response?.data}');
      }
      return {
        'blocked': false,
        'remainingAttempts': 5,
        'minutesLeft': 0,
        'maxAttempts': 5,
      };
    }
  }

  /// сохранение информации о блокировке
  Future<void> saveBlockInfo(int minutesLeft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final blockEndTime = DateTime.now().millisecondsSinceEpoch + (minutesLeft * 60 * 1000);
      await prefs.setInt(blockEndTimeKey, blockEndTime);
    } catch (e) {
      print('Ошибка сохранения информации о блокировке: $e');
    }
  }

  /// получение информации о блокировке
  Future<int?> getBlockEndTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(blockEndTimeKey);
    } catch (e) {
      return null;
    }
  }

  /// очистка информации о блокировке
  Future<void> clearBlockInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(blockEndTimeKey);
      await prefs.remove(remainingAttemptsKey);
    } catch (e) {
      print('Ошибка очистки информации о блокировке: $e');
    }
  }

  /// сохранение оставшихся попыток
  Future<void> saveRemainingAttempts(int attempts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(remainingAttemptsKey, attempts);
    } catch (e) {
      print('Ошибка сохранения попыток: $e');
    }
  }

  /// данная функция выполняет GET запрос
  Future<T> get<T>(String path, {
    Map<String, dynamic>? queryParams,
    T Function(dynamic)? decoder,
    bool isPublic = false,
  }) async {
    final client = isPublic ? await publicDio : await dio;
    
    try {
      final response = await client.get(path, queryParameters: queryParams);
      return _handleResponse(response, decoder);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// данная функция выполняет POST запрос
  Future<T> post<T>(String path, {
    dynamic data,
    T Function(dynamic)? decoder,
    bool isPublic = false,
    bool isFormData = false,
  }) async {
    final client = isPublic ? await publicDio : await dio;
    
    try {
      Options? options;
      if (isFormData) {
        options = Options(contentType: 'multipart/form-data');
      }
      
      final response = await client.post(path, data: data, options: options);
      return _handleResponse(response, decoder);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// данная функция выполняет PUT запрос
  Future<T> put<T>(String path, {
    dynamic data,
    T Function(dynamic)? decoder,
    bool isFormData = false,
  }) async {
    final client = await dio;
    
    try {
      Options? options;
      if (isFormData) {
        options = Options(contentType: 'multipart/form-data');
      }
      
      final response = await client.put(path, data: data, options: options);
      return _handleResponse(response, decoder);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// данная функция выполняет DELETE запрос
  Future<T> delete<T>(String path, {
    T Function(dynamic)? decoder,
  }) async {
    final client = await dio;
    
    try {
      final response = await client.delete(path);
      return _handleResponse(response, decoder);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// данная функция обрабатывает успешный ответ
  T _handleResponse<T>(Response response, T Function(dynamic)? decoder) {
    print('Response ${response.statusCode}: ${response.requestOptions.path}');
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (decoder != null) {
        return decoder(response.data);
      }
      return response.data as T;
    }
    
    throw ApiException(
      message: 'Ошибка сервера: ${response.statusCode}',
      statusCode: response.statusCode,
      data: response.data,
    );
  }

  /// данная функция обрабатывает ошибку Dio
  Exception _handleDioError(DioException e) {
    print('DioError: ${e.type} - ${e.message}');
    
    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final data = e.response!.data;
      
      String errorMessage = _extractErrorMessage(data) ?? 
          'Ошибка сервера: $statusCode';
      
      if (statusCode == 401 && data != null && data is Map) {
        final remainingAttempts = data['remaining_attempts'];
        final maxAttempts = data['max_attempts'];
        final isBlocked = data['blocked'] ?? false;
        final message = data['message'] ?? errorMessage;
        
        if (remainingAttempts != null) {
          saveRemainingAttempts(remainingAttempts);
        }
        
        return ApiException(
          message: message,
          statusCode: statusCode,
          data: data, 
        );
      }
      
      if (statusCode == 429 && data != null && data is Map) {
        final isBlocked = data['blocked'] ?? false;
        final minutesLeft = data['minutes_left'] ?? 0;
        final remainingAttempts = data['remaining_attempts'];
        
        if (isBlocked) {
          saveBlockInfo(minutesLeft);
        }
        if (remainingAttempts != null) {
          saveRemainingAttempts(remainingAttempts);
        }
        
        return ApiException(
          message: data['message'] ?? errorMessage,
          statusCode: statusCode,
          data: data,
        );
      }
      
      return ApiException(
        message: errorMessage,
        statusCode: statusCode,
        data: data,
      );
    }
    
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(message: 'Таймаут соединения с сервером');
      case DioExceptionType.connectionError:
        return const ApiException(message: 'Нет соединения с сервером');
      default:
        return ApiException(message: 'Ошибка: ${e.message}');
    }
  }

  /// данная функция извлекает сообщение об ошибке из данных ответа
  String? _extractErrorMessage(dynamic data) {
    if (data == null) return null;
    
    if (data is Map) {
      if (data.containsKey('detail')) return data['detail'].toString();
      if (data.containsKey('error')) return data['error'].toString();
      if (data.containsKey('message')) return data['message'].toString();
      
      for (var value in data.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
      }
    } else if (data is String) {
      return data;
    }
    
    return null;
  }

  /// данная функция возвращает полный URL изображения
  String getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) return imagePath;
    if (imagePath.startsWith('/media/')) return '$baseUrl$imagePath';
    return '$baseUrl/media/$imagePath';
  }

  /// данная функция выполняет выход из курса
  Future<Map<String, dynamic>> leaveCourse(int userCourseId) async {
    final client = await dio;
    final response = await client.post('/user-courses/$userCourseId/leave/');
    return response.data;
  }

  /// данная функция получает список сертификатов пользователя
  Future<Map<String, dynamic>> getCertificates() async {
    final client = await dio;
    final response = await client.get('/listener/certificates/');
    return response.data;
  }

  /// данная функция проверяет возможность получения сертификата
  Future<Map<String, dynamic>> checkCertificateEligibility(int courseId) async {
    final client = await dio;
    final response = await client.get('/listener/certificates/eligibility/$courseId/');
    return response.data;
  }

  /// данная функция выпускает сертификат
  Future<Map<String, dynamic>> issueCertificate(int courseId) async {
    final client = await dio;
    final response = await client.post('/listener/certificates/issue/$courseId/');
    return response.data;
  }

  /// данная функция скачивает сертификат
  Future<List<int>> downloadCertificate(int certificateId) async {
    final client = await dio;
    final response = await client.get(
      '/listener/certificates/download/$certificateId/',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data;
  }

  /// данная функция создает платеж
  Future<Map<String, dynamic>> createPayment(int courseId) async {
    final client = await dio;
    final response = await client.post('/payments/create/$courseId/');
    return response.data;
  }

  /// данная функция проверяет статус платежа
  Future<Map<String, dynamic>> checkPaymentStatus(String paymentId) async {
    final client = await dio;
    final response = await client.get('/payments/status/$paymentId/');
    return response.data;
  }

  /// данная функция подтверждает платеж
  Future<Map<String, dynamic>> confirmPayment(String paymentId) async {
    final client = await dio;
    final response = await client.post('/payments/confirm/$paymentId/');
    return response.data;
  }

  /// данная функция получает чек
  Future<Map<String, dynamic>> getReceipt(String paymentId) async {
    final client = await dio;
    final response = await client.get('/payments/receipt/$paymentId/');
    return response.data;
  }

  /// данная функция сохраняет файл в локальное хранилище
  Future<String> saveFile(List<int> bytes, String fileName) async {
    try {
      Directory? directory;
      
      if (Platform.isAndroid) {
        directory = await getDownloadsDirectory();
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else if (Platform.isWindows) {
        directory = await getDownloadsDirectory();
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

/// данный класс представляет исключение API
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  const ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  @override
  String toString() => message;
}