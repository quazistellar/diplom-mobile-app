import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String _localBaseUrl = 'http://127.0.0.1:8000';
  static const String _deviceBaseUrl = 'http://10.44.166.31:8000'; 
  
  static String get baseUrl {
    if (Platform.isAndroid || Platform.isIOS) {
      return _deviceBaseUrl;
    } else {
      return _localBaseUrl;
    }
  }
  
  static String get apiUrl => '$baseUrl/api';

  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userEmailKey = 'user_email';
  static const String rememberMeKey = 'remember_me';
  static const String userIdKey = 'user_id';

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  late Dio _dio;
  bool _interceptorSet = false;

  Future<Dio> get dio async {
    await _ensureInitialized();
    return _dio;
  }

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

  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(tokenKey);
    } catch (e) {
      return null;
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(refreshTokenKey);
    } catch (e) {
      return null;
    }
  }

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

  Future<void> saveUserId(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(userIdKey, userId);
    } catch (e) {
      throw Exception('Ошибка сохранения ID пользователя: $e');
    }
  }

  Future<void> clearTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(tokenKey);
      await prefs.remove(refreshTokenKey);
      await prefs.remove(userEmailKey);
      await prefs.remove(rememberMeKey);
      await prefs.remove(userIdKey);
    } catch (e) {
      throw Exception('Ошибка очистки токенов: $e');
    }
  }

  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<String?> getUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(userEmailKey);
    } catch (e) {
      return null;
    }
  }

  Future<int?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(userIdKey);
    } catch (e) {
      return null;
    }
  }

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

  Exception _handleDioError(DioException e) {
    print('DioError: ${e.type} - ${e.message}');
    
    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final data = e.response!.data;
      
      String errorMessage = _extractErrorMessage(data) ?? 
          'Ошибка сервера: $statusCode';
      
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

  String getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) return imagePath;
    if (imagePath.startsWith('/media/')) return '$baseUrl$imagePath';
    return '$baseUrl/media/$imagePath';
  }

  /// покинуть курс
  Future<Map<String, dynamic>> leaveCourse(int userCourseId) async {
    final client = await dio;
    final response = await client.post('/user-courses/$userCourseId/leave/');
    return response.data;
  }


  /// получение списка сертификатов пользователя
  Future<Map<String, dynamic>> getCertificates() async {
    final client = await dio;
    final response = await client.get('/listener/certificates/');
    return response.data;
  }

  /// проверка возможности получения сертификата
  Future<Map<String, dynamic>> checkCertificateEligibility(int courseId) async {
    final client = await dio;
    final response = await client.get('/listener/certificates/eligibility/$courseId/');
    return response.data;
  }

  /// выпуск сертификата
  Future<Map<String, dynamic>> issueCertificate(int courseId) async {
    final client = await dio;
    final response = await client.post('/listener/certificates/issue/$courseId/');
    return response.data;
  }

  /// скачивание сертификата
  Future<List<int>> downloadCertificate(int certificateId) async {
    final client = await dio;
    final response = await client.get(
      '/listener/certificates/download/$certificateId/',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data;
  }

  /// создание платежа
  Future<Map<String, dynamic>> createPayment(int courseId) async {
    final client = await dio;
    final response = await client.post('/payments/create/$courseId/');
    return response.data;
  }

  /// проверка статуса платежа
  Future<Map<String, dynamic>> checkPaymentStatus(String paymentId) async {
    final client = await dio;
    final response = await client.get('/payments/status/$paymentId/');
    return response.data;
  }

  /// подтверждение платежа
  Future<Map<String, dynamic>> confirmPayment(String paymentId) async {
    final client = await dio;
    final response = await client.post('/payments/confirm/$paymentId/');
    return response.data;
  }

  /// получение чека
  Future<Map<String, dynamic>> getReceipt(String paymentId) async {
    final client = await dio;
    final response = await client.get('/payments/receipt/$paymentId/');
    return response.data;
  }

  /// сохранение файла в локальное хранилище
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