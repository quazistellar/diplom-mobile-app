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
  
  final GlobalKey _formKey = GlobalKey();

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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          key: _formKey,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              _buildHeader(context),
              const SizedBox(height: 40),
              _buildWelcomeText(context),
              const SizedBox(height: 32),
              
              _ErrorMessageWidget(),
              const BlockedWarningWidget(),
              
              _buildLoginForm(context),
              const SizedBox(height: 32),
              
              _LoginButtonWidget(
                usernameController: _usernameController,
                passwordController: _passwordController,
                rememberMe: _rememberMe,
                isLoggingIn: _isLoggingIn,
                onLoginStart: () => setState(() => _isLoggingIn = true),
                onLoginEnd: () => setState(() => _isLoggingIn = false),
              ),
              
              const SizedBox(height: 24),
              _buildDivider(context),
              const SizedBox(height: 24),
              _buildToggleMode(context),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Image.asset(
            'assets/icon/unireax_logo.png',
            width: 80,
            height: 80,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.school,
                color: Theme.of(context).colorScheme.primary,
                size: 64,
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'UNIREAX',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeText(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }

  Widget _buildDivider(BuildContext context) {
    final theme = Theme.of(context);
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

  Widget _buildLoginForm(BuildContext context) {
    final theme = Theme.of(context);
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
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                if (!_isLoggingIn && !authProvider.isBlocked) {
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

  Widget _buildToggleMode(BuildContext context) {
    final theme = Theme.of(context);
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
  
  /// функция логина 
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
      
      final isBlocked = await authProvider.checkBlockStatus(username);
      if (isBlocked) {
        if (mounted) {
          SnackBarHelper.showWarning(
            context, 
            'Доступ временно ограничен. Попробуйте через ${authProvider.blockMinutesLeft} минут.'
          );
        }
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
    
  /// диалогоое окно сброса пароля
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

/// виджет ошибки
class _ErrorMessageWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Selector<AuthProvider, String?>(
        selector: (_, provider) => provider.isBlocked ? null : provider.errorMessage,
        builder: (context, errorMessage, child) {
          if (errorMessage == null) return const SizedBox.shrink();
          
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          
          String errorText = errorMessage;
          if (authProvider.remainingAttempts > 0 && 
              authProvider.remainingAttempts < authProvider.maxAttempts &&
              !authProvider.isBlocked) {
            errorText += '. Осталось попыток: ${authProvider.remainingAttempts} из ${authProvider.maxAttempts}';
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
        },
      ),
    );
  }
}

/// вход и кнопа входа
class _LoginButtonWidget extends StatelessWidget {
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool rememberMe;
  final bool isLoggingIn;
  final VoidCallback onLoginStart;
  final VoidCallback onLoginEnd;

  const _LoginButtonWidget({
    required this.usernameController,
    required this.passwordController,
    required this.rememberMe,
    required this.isLoggingIn,
    required this.onLoginStart,
    required this.onLoginEnd,
  });
  
  /// вход в систему
  Future<void> _login(BuildContext context) async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      SnackBarHelper.showWarning(context, 'Заполните все поля');
      return;
    }

    if (isLoggingIn) return;

    onLoginStart();

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final themeManager = Provider.of<ThemeManager>(context, listen: false);
      
      final isBlocked = await authProvider.checkBlockStatus(username);
      if (isBlocked) {
        if (context.mounted) {
          SnackBarHelper.showWarning(
            context, 
            'Доступ временно ограничен. Попробуйте через ${authProvider.blockMinutesLeft} минут.'
          );
        }
        return;
      }
      
      themeManager.setRememberMe(rememberMe);
      authProvider.clearError();
      
      await authProvider.login(username, password, rememberMe);
      
      if (!context.mounted) return;
      
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
      if (context.mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.errorMessage == null) {
          SnackBarHelper.showError(
            context, 
            'Ошибка при входе. Попробуйте снова.',
          );
        }
      }
    } finally {
      onLoginEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Selector<AuthProvider, bool>(
        selector: (_, provider) => provider.isBlocked || provider.isLoading,
        builder: (context, isBlockedOrLoading, child) {
          final isEnabled = !isLoggingIn && !isBlockedOrLoading;
          
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isEnabled ? () => _login(context) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isLoggingIn
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'ВОЙТИ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

/// виджет таймера
class _BlockTimerWidget extends StatefulWidget {
  const _BlockTimerWidget();

  @override
  State<_BlockTimerWidget> createState() => _BlockTimerWidgetState();
}

class _BlockTimerWidgetState extends State<_BlockTimerWidget> {
  int _secondsLeft = 0;
  late final AuthProvider _authProvider;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _secondsLeft = _authProvider.blockSecondsLeft;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _secondsLeft ~/ 60;
    final seconds = _secondsLeft % 60;
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
  }
}

/// виджет блокировки
class BlockedWarningWidget extends StatelessWidget {
  const BlockedWarningWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Selector<AuthProvider, bool>(
        selector: (_, provider) => provider.isBlocked,
        builder: (context, isBlocked, child) {
          if (!isBlocked) return const SizedBox.shrink();
          
          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red, width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Доступ временно ограничен',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Слишком много неудачных попыток входа.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  const _BlockTimerWidget(),
                  const SizedBox(height: 8),
                  Text(
                    'Попробуйте позже',
                    style: TextStyle(
                      color: Colors.red.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}