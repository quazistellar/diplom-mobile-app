import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/snackbar_helper.dart';
import 'verification_dialog.dart';

/// данный класс отображает экран регистрации
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _patronymicController = TextEditingController();
  final _usernameController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isAgreed = false;
  bool _isLoading = false;
  
  bool _hasMinLength = false;
  bool _hasUpperCase = false;
  bool _hasLowerCase = false;
  bool _hasDigit = false;
  bool _hasSpecialChar = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _patronymicController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _validatePassword(String password) {
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUpperCase = password.contains(RegExp(r'[A-Z]'));
      _hasLowerCase = password.contains(RegExp(r'[a-z]'));
      _hasDigit = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Регистрация'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            Center(
              child: Column(
                children: [
                  Icon(Icons.school, color: theme.colorScheme.primary, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'UNIREAX',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            Text(
              'Создайте новый аккаунт',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onBackground,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Заполните все поля для регистрации',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            
            const SizedBox(height: 32),
            
            if (authProvider.errorMessage != null) 
              _buildError(authProvider, theme),
            
            Card(
              color: theme.cardTheme.color,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    TextField(
                      controller: _firstNameController,
                      decoration: InputDecoration(
                        labelText: 'Имя',
                        hintText: 'Иван',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: 'Фамилия',
                        hintText: 'Иванов',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _patronymicController,
                      decoration: InputDecoration(
                        labelText: 'Отчество (необязательно)',
                        hintText: 'Иванович',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Имя пользователя',
                        hintText: 'ivanov123',
                        prefixIcon: const Icon(Icons.badge),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Электронная почта',
                        hintText: 'example@email.com',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          onChanged: _validatePassword,
                          decoration: InputDecoration(
                            labelText: 'Пароль',
                            hintText: 'Введите пароль',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Требования к паролю:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 6,
                                children: [
                                  _buildRequirementChip(
                                    'Минимум 8 символов',
                                    _hasMinLength,
                                    theme,
                                  ),
                                  _buildRequirementChip(
                                    'Заглавная буква',
                                    _hasUpperCase,
                                    theme,
                                  ),
                                  _buildRequirementChip(
                                    'Строчная буква',
                                    _hasLowerCase,
                                    theme,
                                  ),
                                  _buildRequirementChip(
                                    'Цифра',
                                    _hasDigit,
                                    theme,
                                  ),
                                  _buildRequirementChip(
                                    'Спецсимвол (!@#%^&*)',
                                    _hasSpecialChar,
                                    theme,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Подтверждение пароля',
                        hintText: 'Введите пароль еще раз',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _isAgreed,
                            onChanged: (value) {
                              setState(() {
                                _isAgreed = value ?? false;
                              });
                            },
                            activeColor: theme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Нажимая на кнопку "Зарегистрироваться", вы даёте своё согласие на использование ваших персональных данных',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'в соответствие с Федеральным законом от 27.07.2006 №152-ФЗ «О персональных данных» и соглашаетесь с политикой ресурса Unireax',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    if (_isLoading)
                      _buildLoading(theme)
                    else
                      _buildRegisterButton(),
                    
                    const SizedBox(height: 16),
                    
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Уже есть аккаунт? Войти',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementChip(String text, bool isMet, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMet 
            ? Colors.green.withOpacity(0.15)
            : theme.colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMet ? Colors.green : theme.dividerColor,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: isMet ? Colors.green : theme.colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: isMet 
                  ? Colors.green 
                  : theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(AuthProvider authProvider, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              authProvider.errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => authProvider.clearError(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      ),
    );
  }

  Widget _buildRegisterButton() {
    final isPasswordValid = _hasMinLength && _hasUpperCase && _hasLowerCase && _hasDigit && _hasSpecialChar;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isPasswordValid ? _startVerification : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text(
          'ЗАРЕГИСТРИРОВАТЬСЯ',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _startVerification() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      SnackBarHelper.showWarning(context, 'Введите email');
      return;
    }
    
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      SnackBarHelper.showWarning(context, 'Введите корректный email адрес');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.sendVerificationCode(email);
      
      if (success && mounted) {
        final isVerified = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => VerificationDialog(email: email),
        );
        
        if (isVerified == true) {
          await _register();
        }
      } else {
        SnackBarHelper.showError(context, 'Не удалось отправить код подтверждения');
      }
    } catch (e) {
      SnackBarHelper.showError(context, 'Ошибка отправки кода');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _register() async {
    if (!_isAgreed) {
      SnackBarHelper.showWarning(context, 'Необходимо принять соглашение на обработку персональных данных');
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final patronymic = _patronymicController.text.trim();
    final username = _usernameController.text.trim();

    if (email.isEmpty) {
      SnackBarHelper.showWarning(context, 'Введите свою почту!');
      return;
    }

    if (password.isEmpty) {
      SnackBarHelper.showWarning(context, 'Придумайте пароль!');
      return;
    }

    if (confirmPassword.isEmpty) {
      SnackBarHelper.showWarning(context, 'Подтвердите пароль!');
      return;
    }

    if (firstName.isEmpty) {
      SnackBarHelper.showWarning(context, 'Введите своё имя!');
      return;
    }

    if (lastName.isEmpty) {
      SnackBarHelper.showWarning(context, 'Введите свою фамилию!');
      return;
    }

    if (username.isEmpty) {
      SnackBarHelper.showWarning(context, 'Придумайте имя пользователя!');
      return;
    }

    if (password.length < 8) {
      SnackBarHelper.showWarning(context, 'Пароль должен содержать минимум 8 символов');
      return;
    }

    if (password != confirmPassword) {
      SnackBarHelper.showWarning(context, 'Пароли не совпадают');
      return;
    }

    if (username.length < 3) {
      SnackBarHelper.showWarning(context, 'Имя пользователя должно содержать минимум 3 символа');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      await authProvider.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        username: username,
        patronymic: patronymic.isNotEmpty ? patronymic : null,
      );

      if (context.read<AuthProvider>().isAuthenticated && mounted) {
        SnackBarHelper.showSuccess(context, 'Аккаунт успешно создан!');
        Navigator.pushReplacementNamed(context, '/main');
      }
    } catch (e) {
      String errorMessage = 'Ошибка регистрации';
      
      final errorStr = e.toString();
      if (errorStr.contains('already exists') || errorStr.contains('уже существует')) {
        if (errorStr.contains('username') || errorStr.contains('имя пользователя')) {
          errorMessage = 'Имя пользователя уже занято';
        } else if (errorStr.contains('email') || errorStr.contains('почта')) {
          errorMessage = 'Email уже зарегистрирован';
        }
      } else if (errorStr.contains('detail:')) {
        errorMessage = errorStr.split('detail:').last.trim();
      } else if (errorStr.contains('400')) {
        errorMessage = 'Некорректные данные регистрации';
      } else if (errorStr.contains('Connection') || errorStr.contains('timeout')) {
        errorMessage = 'Ошибка подключения к серверу';
      }
      
      SnackBarHelper.showError(context, errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}