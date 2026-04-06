import 'dart:async';
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
  
  bool _isBlocked = false;
  int _remainingAttempts = 5;
  int _maxAttempts = 5;
  int _blockMinutesLeft = 0;
  int _blockSecondsLeft = 0; 
  Timer? _blockTimer;
  
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _currentUser;
  bool get isLoginInProgress => _isLoginInProgress; 
  bool get isAuthenticated => _currentUser != null;
  
  bool get isBlocked => _isBlocked;
  int get remainingAttempts => _remainingAttempts;
  int get maxAttempts => _maxAttempts;
  int get blockMinutesLeft => _blockMinutesLeft;
  int get blockSecondsLeft => _blockSecondsLeft; 

  /// данная функция проверяет статус блокировки перед входом
  Future<bool> checkBlockStatus(String username) async {
    if (username.isEmpty) {
      return false;
    }
    
    try {
      final status = await _apiClient.checkLoginStatus(username);
      _isBlocked = status['blocked'] ?? false;
      _remainingAttempts = status['remainingAttempts'] ?? 5;
      _maxAttempts = status['maxAttempts'] ?? 5;
      _blockMinutesLeft = status['minutesLeft'] ?? 0;
      _blockSecondsLeft = _blockMinutesLeft * 60; 
      if (_isBlocked && _blockSecondsLeft > 0) {
        _startBlockTimer();
      }
      
      notifyListeners();
      return _isBlocked;
    } catch (e) {
      return false;
    }
  }

  /// данная функция запускает таймер блокировки (обратный отсчет в секундах)
  void _startBlockTimer() {
    _blockTimer?.cancel();
    _blockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_blockSecondsLeft > 0) {
        _blockSecondsLeft--;
        _blockMinutesLeft = (_blockSecondsLeft / 60).ceil();
        notifyListeners();
      } else {
        _blockTimer?.cancel();
        _isBlocked = false;
        _blockMinutesLeft = 0;
        _blockSecondsLeft = 0;
        _apiClient.clearBlockInfo();
        notifyListeners();
      }
    });
  }

  /// данная функция выполняет вход пользователя в систему
  Future<void> login(String username, String password, bool rememberMe) async {
    if (_isLoginInProgress) return;
    
    _isLoginInProgress = true;
    _setLoading(true);
    _clearError();

    try {
      print('AuthProvider: начало авторизации...');
      
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/login/',
        data: {'username': username, 'password': password, 'remember_me': rememberMe},
        isPublic: true,
      );
      
      final accessToken = response['access'];
      final refreshToken = response['refresh'];
      
      if (accessToken == null || refreshToken == null) {
        throw const ApiException(message: 'Сервер не вернул токены авторизации');
      }
      
      await _apiClient.saveTokens(accessToken, refreshToken, username, rememberMe);
      await _apiClient.clearBlockInfo();
      await _loadCurrentUser();
      
      _isBlocked = false;
      _remainingAttempts = _maxAttempts;
      _blockMinutesLeft = 0;
      _blockSecondsLeft = 0;
      _blockTimer?.cancel();
      
      if (_currentUser == null) {
        throw const ApiException(message: 'Не удалось загрузить данные пользователя');
      }
      
      notifyListeners();
      
    } catch (e) {
      _errorMessage = _parseErrorMessage(e);
      
      if (e is ApiException && e.data != null) {
        if (e.data is Map) {
          final errorData = e.data as Map<String, dynamic>;
          
          if (errorData.containsKey('remaining_attempts')) {
            _remainingAttempts = errorData['remaining_attempts'];
          }
          
          if (errorData.containsKey('blocked') && errorData['blocked'] == true) {
            _isBlocked = true;
            _blockMinutesLeft = errorData['minutes_left'] ?? 0;
            _blockSecondsLeft = _blockMinutesLeft * 60;
            _startBlockTimer();
          }
          
          if (errorData.containsKey('max_attempts')) {
            _maxAttempts = errorData['max_attempts'];
          }
          
          notifyListeners();
        }
      }
      
      await _apiClient.clearTokens();
      _currentUser = null;
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
      _isLoginInProgress = false;
    }
  }

  /// данная функция выполняет регистрацию нового пользователя
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
      
      await _apiClient.clearBlockInfo();
      _isBlocked = false;
      _remainingAttempts = _maxAttempts;
      _blockMinutesLeft = 0;
      _blockSecondsLeft = 0;
      _blockTimer?.cancel();
      
      await _loadCoursesData();
      
    } catch (e) {
      _errorMessage = _parseErrorMessage(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// данная функция выполняет выход пользователя из системы
  Future<void> logout() async {
    try {
      _setLoading(true);
      await _apiClient.clearTokens();
      await _apiClient.clearBlockInfo();
      _currentUser = null;
      _isBlocked = false;
      _remainingAttempts = _maxAttempts;
      _blockMinutesLeft = 0;
      _blockSecondsLeft = 0;
      _blockTimer?.cancel();
      notifyListeners();
    } catch (e) {
      print('Ошибка при выходе: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// данная функция проверяет статус авторизации пользователя
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

  /// данная функция загружает данные текущего пользователя
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

  /// данная функция загружает данные курсов пользователя
  Future<void> _loadCoursesData() async {
    notifyListeners();
  }

  /// данная функция обновляет данные пользователя
  Future<void> refreshUserData() async {
    if (isAuthenticated) {
      await _loadCurrentUser();
    }
  }

  /// данная функция обновляет профиль пользователя
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

  /// данная функция изменяет пароль пользователя
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

  /// данная функция очищает сообщение об ошибке
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// данная функция сбрасывает состояние авторизации
  void resetAuthState() {
    _currentUser = null;
    _isBlocked = false;
    _remainingAttempts = _maxAttempts;
    _blockMinutesLeft = 0;
    _blockSecondsLeft = 0;
    _blockTimer?.cancel();
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

  /// данная функция парсит сообщение об ошибке
  String _parseErrorMessage(dynamic e) {
    
    if (e is ApiException) {
      
      if (e.data != null && e.data is Map) {
        final errorData = e.data as Map<String, dynamic>;
        
        if (errorData.containsKey('remaining_attempts')) {
          _remainingAttempts = errorData['remaining_attempts'];
          _maxAttempts = errorData['max_attempts'] ?? 5;
          notifyListeners();
        }
        
        if (errorData.containsKey('blocked') && errorData['blocked'] == true) {
          _isBlocked = true;
          _blockMinutesLeft = errorData['minutes_left'] ?? 0;
          _blockSecondsLeft = _blockMinutesLeft * 60;
          _startBlockTimer();
          notifyListeners();
        }
        
        if (errorData.containsKey('message')) {
          return _translateErrorMessage(errorData['message'].toString());
        }
        
        if (errorData.containsKey('detail')) {
          return _translateErrorMessage(errorData['detail'].toString());
        }
        
        if (errorData.containsKey('error')) {
          return _translateErrorMessage(errorData['error'].toString());
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
    
    if (e.toString().contains('429')) {
      return 'Слишком много попыток входа. Попробуйте позже.';
    }
    
    return 'Ошибка авторизации. Попробуйте позже.';
  }

  /// данная функция переводит сообщение об ошибке
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
      'Too many login attempts': 'Слишком много попыток входа',
    };
    
    for (var entry in translations.entries) {
      if (message.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return message;
  }

  /// данная функция переводит название поля
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
  
  @override
  void dispose() {
    _blockTimer?.cancel();
    super.dispose();
  }
}