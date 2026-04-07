import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_client.dart';
import '../utils/snackbar_helper.dart';
import 'register_screen.dart';
import 'password_reset_screen.dart';

/// класс отображает экран авторизации
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  
  bool _rememberMe = true;
  bool _obscurePassword = true;
  bool _isLoadingCredentials = false;
  bool _isLoggingIn = false;
  bool _isDialogOpen = false;
  
  bool _initialLoadDone = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentialsOnce();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  /// загружает сохраненные учетные данные 
  Future<void> _loadSavedCredentialsOnce() async {
    if (_initialLoadDone || _isLoadingCredentials || !mounted) return;
    
    _initialLoadDone = true;
    setState(() => _isLoadingCredentials = true);
    
    try {
      final themeManager = Provider.of<ThemeManager>(context, listen: false);
      final shouldRemember = themeManager.rememberMe;
      
      if (shouldRemember && mounted) {
        final savedEmail = await ApiClient().getUserEmail();
        if (savedEmail != null && mounted) {
          setState(() {
            _usernameController.text = savedEmail;
            _rememberMe = true;
          });
        }
      }
    } catch (e) {
      print('Ошибка загрузки сохраненных данных: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingCredentials = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeManager = context.watch<ThemeManager>();
    final theme = themeManager.currentTheme;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.school,
                      color: theme.colorScheme.primary,
                      size: 64,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'UNIREAX',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              
              Text(
                'Добро пожаловать!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Войдите в свой аккаунт UNIREAX',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              
              const SizedBox(height: 32),
              
              Selector<AuthProvider, String?>(
                selector: (_, provider) => provider.errorMessage,
                builder: (context, errorMessage, child) {
                  if (errorMessage != null && !authProvider.isBlocked) {
                    return _buildError(authProvider, theme, authProvider.remainingAttempts);
                  }
                  return const SizedBox.shrink();
                },
              ),
              
              const BlockedWarningWidget(),
              
              _buildLoginForm(theme),
              const SizedBox(height: 32),
              
              Selector<AuthProvider, bool>(
                selector: (_, provider) => provider.isLoading,
                builder: (context, isLoading, child) {
                  if (_isLoggingIn || isLoading) {
                    return _buildLoading(theme);
                  }
                  if (!authProvider.isBlocked) {
                    return _buildLoginButton(authProvider, themeManager);
                  }
                  return const SizedBox.shrink();
                },
              ),
              
              const SizedBox(height: 24),
              _buildDivider(theme),
              const SizedBox(height: 24),
              _buildToggleMode(theme),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  /// виджет-разделитель "ИЛИ"
  Widget _buildDivider(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: theme.colorScheme.onSurface.withOpacity(0.3),
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'ИЛИ',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: theme.colorScheme.onSurface.withOpacity(0.3),
            thickness: 1,
          ),
        ),
      ],
    );
  }

  /// виджет ошибки
  Widget _buildError(AuthProvider authProvider, ThemeData theme, int remainingAttempts) {
    String errorText = authProvider.errorMessage ?? 'Неверное имя пользователя или пароль';
    if (remainingAttempts > 0 && remainingAttempts < authProvider.maxAttempts) {
      errorText += '. Осталось попыток: $remainingAttempts из ${authProvider.maxAttempts}';
    }
    
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
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorText,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ),
          GestureDetector(
            onTap: () => authProvider.clearError(),
            child: const Icon(Icons.close, size: 18, color: Colors.red),
          ),
        ],
      ),
    );
  }

  /// данная функция создает виджет формы входа
  Widget _buildLoginForm(ThemeData theme) {
    return Card(
      color: theme.cardTheme.color,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Имя пользователя',
                hintText: 'Введите имя пользователя',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onSubmitted: (_) => _passwordFocusNode.requestFocus(),
            ),
            const SizedBox(height: 20),
            
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              focusNode: _passwordFocusNode,
              decoration: InputDecoration(
                labelText: 'Пароль',
                hintText: 'Введите пароль',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onSubmitted: (_) {
                if (!_isLoggingIn) {
                  _login();
                }
              },
            ),
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() => _rememberMe = value ?? false);
                        },
                        activeColor: theme.colorScheme.primary,
                        checkColor: Colors.white,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Запомнить меня',
                      style: TextStyle(
                        color: theme.colorScheme.onBackground,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _isDialogOpen || 
                      Provider.of<AuthProvider>(context, listen: false).isBlocked 
                      ? null 
                      : _showPasswordResetDialog,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Забыли пароль?',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// данная функция создает виджет переключения на регистрацию
  Widget _buildToggleMode(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Нет аккаунта?',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RegisterScreen(),
              ),
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Зарегистрироваться',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.person_add_outlined,
                color: theme.colorScheme.primary,
                size: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// данная функция создает виджет загрузки
  Widget _buildLoading(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: CircularProgressIndicator(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  /// данная функция создает кнопку входа
  Widget _buildLoginButton(AuthProvider authProvider, ThemeManager themeManager) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoggingIn || authProvider.isLoading 
            ? null
            : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'ВОЙТИ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: 18),
          ],
        ),
      ),
    );
  }

  /// данная функция выполняет вход пользователя
  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      SnackBarHelper.showWarning(context, 'Заполните все поля');
      return;
    }

    if (_isLoggingIn) return;

    setState(() => _isLoggingIn = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final themeManager = Provider.of<ThemeManager>(context, listen: false);
      
      final isBlocked = await authProvider.checkBlockStatus();
      if (isBlocked) {
        if (mounted) {
          SnackBarHelper.showWarning(
            context, 
            'Доступ временно ограничен. Попробуйте через ${authProvider.blockMinutesLeft} минут.'
          );
        }
        setState(() => _isLoggingIn = false);
        return;
      }
      
      themeManager.setRememberMe(_rememberMe);
      authProvider.clearError();
      
      print('Вход пользователя с именем: $username');
      
      await authProvider.login(username, password, _rememberMe);
      
      if (!mounted) return;
      
      if (authProvider.currentUser != null) {        
        SnackBarHelper.showSuccess(
          context, 
          'Добро пожаловать, ${authProvider.currentUser!.firstName ?? username}!',
        );
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        SnackBarHelper.showError(
          context, 
          authProvider.errorMessage ?? 'Ошибка при входе',
        );
      }
      
    } catch (e) {
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.errorMessage == null) {
          SnackBarHelper.showError(
            context, 
            'Ошибка при входе. Попробуйте снова.',
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
      }
    }
  }
    
  /// данная функция показывает диалог восстановления пароля
  void _showPasswordResetDialog() {
    if (_isDialogOpen) return;
    
    _isDialogOpen = true;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        String email = '';
        final theme = Theme.of(context);
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: theme.dialogTheme.backgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Row(
                children: [
                  Icon(Icons.lock_reset, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Восстановление пароля',
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Введите email вашего аккаунта. Мы отправим код восстановления.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    onChanged: (value) {
                      email = value;
                    },
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Введите ваш email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: Text(
                    'ОТМЕНА',
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (email.isEmpty || !email.contains('@')) {
                      SnackBarHelper.showWarning(dialogContext, 'Введите корректный email');
                      return;
                    }
                    Navigator.pop(dialogContext, email);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('ОТПРАВИТЬ КОД'),
                ),
              ],
            );
          },
        );
      },
    ).then((email) {
      if (mounted) {
        setState(() {
          _isDialogOpen = false;
        });
      }

      if (email != null && email is String && email.isNotEmpty) {
        Future.microtask(() {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PasswordResetScreen(email: email),
              ),
            );
          }
        });
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _isDialogOpen = false;
        });
      }
      print('Ошибка при открытии диалога: $error');
    });
  }
}

/// виджет для отображения таймера блокировки
class BlockTimerWidget extends StatelessWidget {
  const BlockTimerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Provider.of<AuthProvider>(context, listen: false).timerStream,
      initialData: Provider.of<AuthProvider>(context, listen: false).blockSecondsLeft,
      builder: (context, snapshot) {
        final secondsLeft = snapshot.data ?? 0;
        final minutes = secondsLeft ~/ 60;
        final seconds = secondsLeft % 60;
        final timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer, color: Colors.red, size: 16),
              const SizedBox(width: 8),
              Text(
                timeString,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// виджет блокировки, который перестраивается только при изменении статуса блокировки
class BlockedWarningWidget extends StatelessWidget {
  const BlockedWarningWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AuthProvider, bool>(
      selector: (_, provider) => provider.isBlocked,
      builder: (context, isBlocked, child) {
        if (!isBlocked) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red, width: 1.5),
          ),
          child: Column(
            children: [
              const Icon(Icons.lock_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Доступ временно ограничен',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Слишком много неудачных попыток входа.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const BlockTimerWidget(),
              const SizedBox(height: 4),
              Text(
                'Попробуйте позже',
                style: TextStyle(
                  color: Colors.red.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}