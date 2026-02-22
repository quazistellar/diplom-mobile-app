import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import 'course_provider.dart';
import 'user_course_provider.dart';

class AuthProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _isLoginInProgress = false;
  User? _currentUser;
  
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _currentUser;
  bool get isLoginInProgress => _isLoginInProgress; 
  bool get isAuthenticated => _currentUser != null;

 Future<void> login(String username, String password, bool rememberMe) async {
  if (_isLoginInProgress) return; 
  
  _isLoginInProgress = true; 
  _setLoading(true);
  _clearError();

  try {
    print('AuthProvider: начало авторизации...');
    
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/auth/token/',
      data: {'username': username, 'password': password},
      isPublic: true,
    );
    
    final accessToken = response['access'];
    final refreshToken = response['refresh'];
    
    if (accessToken == null || refreshToken == null) {
      throw const ApiException(message: 'Сервер не вернул токены авторизации');
    }
    
    await _apiClient.saveTokens(accessToken, refreshToken, username, rememberMe);
    await _loadCurrentUser();
    
    if (_currentUser == null) {
      throw const ApiException(message: 'Не удалось загрузить данные пользователя');
    }
    
    notifyListeners();
    
  } catch (e) {
    _errorMessage = _parseErrorMessage(e);
    await _apiClient.clearTokens();
    _currentUser = null;
    rethrow;
  } finally {
    _setLoading(false);
    _isLoginInProgress = false; 
  }
}

  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String username,
    String? patronymic, 
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final Map<String, dynamic> requestData = {
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'username': username,
        'confirm_password': password,
      };
      
      if (patronymic != null && patronymic.isNotEmpty) {
        requestData['patronymic'] = patronymic;
      }
      
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/register/',
        data: requestData,
        isPublic: true,
      );
      
      final accessToken = response['access'];
      final refreshToken = response['refresh'];
      
      if (accessToken != null && refreshToken != null) {
        await _apiClient.saveTokens(accessToken, refreshToken, email, true);
      }
      
      if (response['user'] != null) {
        _currentUser = User.fromJson(response['user']);
        await _apiClient.saveUserId(_currentUser!.id);
      }
      
      await _loadCoursesData();
      
    } catch (e) {
      _errorMessage = _parseErrorMessage(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    try {
      _setLoading(true);
      await _apiClient.clearTokens();
      _currentUser = null;

      
    } catch (e) {
      print('Ошибка при выходе: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> checkAuth() async {
  try {
    
    if (_currentUser != null) {
      return true;
    }
    
    final isAuthenticated = await _apiClient.isAuthenticated();
    
    if (isAuthenticated) {

      try {
        await _loadCurrentUser();
        
        if (_currentUser != null) {
          await _loadCoursesData();
          return true;
        } else {
          await _apiClient.clearTokens();
          return false;
        }
      } catch (e) {
        await _apiClient.clearTokens();
        return false;
      }
    }
    return false;
  } catch (e) {
    return false;
  }
}

  Future<void> _loadCurrentUser() async {
    try {
      final userData = await _apiClient.get<Map<String, dynamic>>('/users/me/');
      _currentUser = User.fromJson(userData);
      await _apiClient.saveUserId(_currentUser!.id);
      notifyListeners();
    } catch (e) {
      await _apiClient.clearTokens();
      _currentUser = null;
      rethrow;
    }
  }

  Future<void> _loadCoursesData() async {
    notifyListeners();
  }

  Future<void> refreshUserData() async {
    if (isAuthenticated) {
      await _loadCurrentUser();
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiClient.put<Map<String, dynamic>>(
        '/users/update_profile/',
        data: data,
      );
      _currentUser = User.fromJson(response);
      notifyListeners();
    } catch (e) {
      throw Exception('Ошибка обновления профиля: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    _setLoading(true);
    _clearError();

    try {
      await _apiClient.post(
        '/users/change_password/',
        data: {
          'old_password': oldPassword,
          'new_password': newPassword,
          'confirm_password': newPassword,
        },
      );
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void resetAuthState() {
    _currentUser = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }


 String _parseErrorMessage(dynamic e) {
    if (e is ApiException) {
      if (e.data != null) {
        if (e.data is Map) {
          final errorData = e.data as Map<String, dynamic>;
          
          if (errorData.containsKey('detail')) {
            return _translateErrorMessage(errorData['detail'].toString());
          }
          
          if (errorData.containsKey('non_field_errors') && errorData['non_field_errors'] is List) {
            final errors = errorData['non_field_errors'] as List;
            if (errors.isNotEmpty) {
              return _translateErrorMessage(errors.first.toString());
            }
          }
          
          if (errorData.containsKey('error')) {
            return _translateErrorMessage(errorData['error'].toString());
          }
          
          if (errorData.containsKey('message')) {
            return _translateErrorMessage(errorData['message'].toString());
          }
          
          final fieldErrors = <String>[];
          errorData.forEach((key, value) {
            if (key != 'detail' && key != 'non_field_errors') {
              if (value is List && value.isNotEmpty) {
                fieldErrors.add('${_translateFieldName(key)}: ${_translateErrorMessage(value.first.toString())}');
              } else if (value is String) {
                fieldErrors.add('${_translateFieldName(key)}: ${_translateErrorMessage(value)}');
              }
            }
          });
          
          if (fieldErrors.isNotEmpty) {
            return fieldErrors.join('\n');
          }
        }
      }
      
      return _translateErrorMessage(e.message);
    }
    
    if (e.toString().contains('No active account found')) {
      return 'Неверное имя пользователя или пароль';
    }
    
    if (e.toString().contains('Unable to log in')) {
      return 'Не удалось войти. Проверьте введенные данные.';
    }
    
    if (e.toString().contains('Connection refused') || 
        e.toString().contains('SocketException')) {
      return 'Нет подключения к серверу. Проверьте интернет-соединение.';
    }
    
    return 'Ошибка авторизации. Попробуйте позже.';
  }

  String _translateErrorMessage(String message) {
    final Map<String, String> translations = {
      'No active account found with the given credentials': 'Неверное имя пользователя или пароль',
      'Unable to log in with provided credentials': 'Не удалось войти с указанными учетными данными',
      'User account is disabled': 'Аккаунт пользователя отключен',
      'password incorrect': 'Неверный пароль',
      'username not found': 'Пользователь не найден',
      'email not found': 'Email не найден',
      'This field is required': 'Обязательное поле',
      'Invalid token': 'Недействительный токен',
      'Token expired': 'Срок действия токена истек',
      'Authentication credentials were not provided': 'Не предоставлены учетные данные',
      'User with this email already exists': 'Пользователь с таким email уже существует',
      'User with this username already exists': 'Пользователь с таким именем уже существует',
      'Passwords do not match': 'Пароли не совпадают',
      'Password is too common': 'Слишком простой пароль',
      'Password is too short': 'Пароль слишком короткий',
      'This password is too common': 'Этот пароль слишком простой',
      'This password is entirely numeric': 'Пароль не может состоять только из цифр',
    };
    
    for (var entry in translations.entries) {
      if (message.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return message;
  }

  String _translateFieldName(String fieldName) {
    final Map<String, String> fieldTranslations = {
      'username': 'Имя пользователя',
      'email': 'Email',
      'password': 'Пароль',
      'first_name': 'Имя',
      'last_name': 'Фамилия',
      'patronymic': 'Отчество', 
      'old_password': 'Старый пароль',
      'new_password': 'Новый пароль',
      'confirm_password': 'Подтверждение пароля',
    };
    
    return fieldTranslations[fieldName] ?? fieldName;
  }
}