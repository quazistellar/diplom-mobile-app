import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../providers/theme_provider.dart';

class PasswordResetScreen extends StatefulWidget {
  final String email;
  
  const PasswordResetScreen({super.key, required this.email});
  
  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final ApiClient _apiClient = ApiClient();
  
  final List<TextEditingController> _codeControllers = List.generate(6, (_) => TextEditingController());
  final FocusNode _focusNode = FocusNode();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isSendingCode = false;
  String _errorMessage = '';
  String _successMessage = '';
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  int _step = 1; // p.s: это шаги для изменения пароля, 1 - ввод кода, 2 - ввод нового пароля
  String? _verifiedCode;
  bool _canResendCode = false;
  int _resendTimer = 0;
  late Timer _timer;
  
  @override
  void initState() {
    super.initState();
    _startResendTimer();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendInitialCode();
    });
  }
  
  @override
  void dispose() {
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _focusNode.dispose();
    _timer.cancel();
    super.dispose();
  }
  
  void _startResendTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendTimer > 0) {
            _resendTimer--;
          } else {
            _canResendCode = true;
          }
        });
      }
    });
  }
  
  Future<void> _sendInitialCode() async {
    if (_isSendingCode) return;
    
    setState(() {
      _isSendingCode = true;
      _errorMessage = '';
      _successMessage = 'Отправляем код на ${widget.email}...';
    });
    
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/password-reset/request/',
        data: {'email': widget.email},
        isPublic: true,
      );
      
      if (response['detail'] == 'Код восстановления отправлен на email' || 
          response['success'] == true) {
        setState(() {
          _successMessage = 'Код отправлен на ${widget.email}. Проверьте почту.';
          _canResendCode = false;
          _resendTimer = 60;
        });
        
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _focusNode.requestFocus();
        });
      } else {
        setState(() => _errorMessage = response['detail'] ?? 'Ошибка отправки кода');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Ошибка отправки кода: $e');
    } finally {
      setState(() => _isSendingCode = false);
    }
  }
  
  Future<void> _verifyCode() async {
    final code = _codeControllers.map((c) => c.text).join();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Введите полный 6-значный код');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });
    
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/password-reset/verify/',
        data: {'email': widget.email, 'code': code},
        isPublic: true,
      );
      
      if (response['detail'] == 'Код подтвержден' || 
          response['valid'] == true ||
          response['is_valid'] == true) {
        setState(() {
          _verifiedCode = code;
          _step = 2;
          _successMessage = 'Код подтвержден! Теперь задайте новый пароль.';
        });
      } else {
        setState(() => _errorMessage = response['detail'] ?? 'Неверный код');
      }
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('Неверный код')) {
        setState(() => _errorMessage = 'Неверный код подтверждения');
      } else if (errorMessage.contains('Срок действия кода истек')) {
        setState(() => _errorMessage = 'Срок действия кода истек. Запросите новый код.');
      } else {
        setState(() => _errorMessage = 'Ошибка проверки кода: $errorMessage');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _resetPassword() async {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() => _errorMessage = 'Заполните все поля');
      return;
    }
    
    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = 'Пароли не совпадают');
      return;
    }
    
    if (newPassword.length < 8) {
      setState(() => _errorMessage = 'Пароль должен содержать минимум 8 символов');
      return;
    }
    
    if (_verifiedCode == null) {
      setState(() => _errorMessage = 'Сначала подтвердите код');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/password-reset/confirm/',
        data: {
          'email': widget.email,
          'code': _verifiedCode!,
          'new_password': newPassword,
          'confirm_password': newPassword,
        },
        isPublic: true,
      );
      
      if (response['detail'] == 'Пароль успешно изменен' || 
          response['success'] == true) {
        setState(() => _successMessage = 'Пароль успешно изменен! Через 3 секунды вы вернетесь на экран входа.');
        
        await Future.delayed(const Duration(seconds: 3));
        
        if (mounted) Navigator.pop(context, true);
      } else {
        setState(() => _errorMessage = response['detail'] ?? 'Ошибка изменения пароля');
      }
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('Неверный код')) {
        setState(() => _errorMessage = 'Код недействителен. Запросите новый код.');
      } else if (errorMessage.contains('Срок действия кода истек')) {
        setState(() => _errorMessage = 'Срок действия кода истек. Начните восстановление заново.');
      } else {
        setState(() => _errorMessage = 'Ошибка изменения пароля: $errorMessage');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _resendCode() async {
    if (!_canResendCode || _isSendingCode) return;
    
    setState(() {
      _isSendingCode = true;
      _errorMessage = '';
      _successMessage = 'Отправляем новый код...';
      _canResendCode = false;
      _resendTimer = 60;
    });
    
    for (var controller in _codeControllers) {
      controller.clear();
    }
    
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/password-reset/request/',
        data: {'email': widget.email},
        isPublic: true,
      );
      
      if (response['detail'] == 'Код восстановления отправлен на email' || 
          response['success'] == true) {
        setState(() => _successMessage = 'Новый код отправлен на ${widget.email}');
        if (mounted) _focusNode.requestFocus();
      } else {
        setState(() => _errorMessage = response['detail'] ?? 'Ошибка отправки кода');
        _canResendCode = true;
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка отправки кода: $e';
        _canResendCode = true;
      });
    } finally {
      setState(() => _isSendingCode = false);
    }
  }
  
  Widget _buildCodeInputStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Введите 6-значный код',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Код отправлен на ${widget.email}',
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 24),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return Container(
              width: 50,
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: TextField(
                controller: _codeControllers[index],
                focusNode: index == 0 ? _focusNode : null,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5), width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                onChanged: (value) {
                  if (value.length == 1 && index < 5) {
                    FocusScope.of(context).nextFocus();
                  } else if (value.isEmpty && index > 0) {
                    FocusScope.of(context).previousFocus();
                  }
                  
                  if (value.length == 1 && index == 5) {
                    Future.delayed(const Duration(milliseconds: 300), _verifyCode);
                  }
                  
                  if (_errorMessage.isNotEmpty) setState(() => _errorMessage = '');
                },
              ),
            );
          }),
        ),
        
        const SizedBox(height: 20),
        
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.access_time, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.7)),
              const SizedBox(width: 8),
              Text(
                'Не пришел код?',
                style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
              ),
              const SizedBox(width: 8),
              if (_canResendCode && !_isSendingCode)
                TextButton(
                  onPressed: _resendCode,
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                  child: Text(
                    'Отправить снова',
                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                  ),
                )
              else if (_isSendingCode)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Text(
                  'Отправить снова через $_resendTimer сек',
                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontWeight: FontWeight.w500),
                ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Проверьте папку "Спам", если не видите письмо',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.8)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildNewPasswordStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Введите новый пароль',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Придумайте надежный пароль для аккаунта ${widget.email}',
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 24),
        
        TextField(
          controller: _newPasswordController,
          obscureText: _obscureNewPassword,
          decoration: InputDecoration(
            labelText: 'Новый пароль',
            hintText: 'Минимум 8 символов',
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (_) {
            if (_errorMessage.isNotEmpty) setState(() => _errorMessage = '');
          },
        ),
        
        const SizedBox(height: 16),
        
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Подтвердите пароль',
            hintText: 'Повторите пароль',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onSubmitted: (_) => _resetPassword(),
          onChanged: (_) {
            if (_errorMessage.isNotEmpty) setState(() => _errorMessage = '');
          },
        ),
        
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.security, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Рекомендации для надежного пароля:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '• Минимум 8 символов\n'
                '• Используйте буквы верхнего и нижнего регистра\n'
                '• Добавьте цифры (например: 1, 2, 3)\n'
                '• Добавьте специальные символы (например: !, @, #)\n'
                '• Не используйте простые пароли (qwerty, 123456)',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final theme = themeManager.currentTheme;
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: const Text('Восстановление пароля'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _step == 1 ? 'Подтвердите email' : 'Создайте новый пароль',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _step == 1 
                ? 'Введите 6-значный код из письма' 
                : 'Введите новый пароль для аккаунта',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            
            const SizedBox(height: 32),
            
            if (_errorMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: Colors.red,
                      onPressed: () => setState(() => _errorMessage = ''),
                    ),
                  ],
                ),
              ),
            
            if (_successMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _successMessage,
                        style: const TextStyle(color: Colors.green, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            
            _step == 1 ? _buildCodeInputStep(theme) : _buildNewPasswordStep(theme),
            
            const SizedBox(height: 32),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isLoading || _isSendingCode) ? null : () {
                  if (_step == 1) _verifyCode();
                  else _resetPassword();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isLoading
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _step == 1 ? 'ПОДТВЕРДИТЬ КОД' : 'СОХРАНИТЬ ПАРОЛЬ',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                    ),
              ),
            ),
            
            if (_step == 1) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: Text(
                    'Вернуться к вводу email',
                    style: TextStyle(color: theme.colorScheme.primary, fontSize: 14),
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Важная информация',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _step == 1 
                      ? '• Код действителен в течение 15 минут\n'
                        '• После смены пароля все активные сессии будут завершены\n'
                        '• Если код не пришел, проверьте папку "Спам"\n'
                        '• Убедитесь, что вводите email, на который зарегистрирован аккаунт'
                      : '• Пароль должен быть уникальным и не использоваться в других сервисах\n'
                        '• После изменения пароля потребуется войти заново\n'
                        '• Сохраните пароль в надежном месте',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}