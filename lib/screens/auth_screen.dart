import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_client.dart';
import '../utils/snackbar_helper.dart';
import 'register_screen.dart';
import 'password_reset_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoadingCredentials = false;
  bool _isLoggingIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedCredentials();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    if (_isLoadingCredentials) return;
    
    setState(() => _isLoadingCredentials = true);
    
    try {
      final themeManager = Provider.of<ThemeManager>(context, listen: false);
      final shouldRemember = themeManager.rememberMe;
      
      if (shouldRemember) {
        final savedEmail = await ApiClient().getUserEmail();
        if (savedEmail != null && mounted) {
          _usernameController.text = savedEmail;
          _rememberMe = true;
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
      body: SingleChildScrollView(
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
              'Вход в систему',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Введите данные для входа в ваш аккаунт',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            
            const SizedBox(height: 32),
            
            if (authProvider.errorMessage != null) 
              _buildError(authProvider, theme),
            
            _buildLoginForm(theme),
            const SizedBox(height: 32),
            
            if (_isLoggingIn || authProvider.isLoading)
              _buildLoading(theme)
            else
              _buildLoginButton(authProvider, themeManager),
            
            const SizedBox(height: 24),
            
            Center(
              child: TextButton(
                onPressed: () => _showPasswordResetDialog(theme),
                child: Text(
                  'Забыли пароль?',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            _buildToggleMode(theme),
            const SizedBox(height: 48),
          ],
        ),
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

  Widget _buildLoginForm(ThemeData theme) {
    return Card(
      color: theme.cardTheme.color,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Имя пользователя',
                hintText: 'Введите ваш username',
                prefixIcon: const Icon(Icons.person),
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
                prefixIcon: const Icon(Icons.lock),
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
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: (value) {
                    setState(() => _rememberMe = value ?? false);
                  },
                  activeColor: theme.colorScheme.primary,
                  checkColor: Colors.white,
                ),
                Text(
                  'Запомнить меня',
                  style: TextStyle(
                    color: theme.colorScheme.onBackground,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
          child: Text(
            'Зарегистрироваться',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

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
        child: const Text(
          'ВОЙТИ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }


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
        SnackBarHelper.showError(
          context, 
          authProvider.errorMessage ?? 'Ошибка при входе. Попробуйте снова.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
      }
    }
  }
    
  void _showPasswordResetDialog(ThemeData theme) {
    final TextEditingController emailController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.dialogTheme.backgroundColor,
          title: Text(
            'Восстановление пароля',
            style: TextStyle(color: theme.colorScheme.onSurface),
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
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Введите ваш email',
                  prefixIcon: const Icon(Icons.email),
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
              onPressed: () => Navigator.pop(context),
              child: Text(
                'ОТМЕНА',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final email = emailController.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  SnackBarHelper.showWarning(context, 'Введите корректный email');
                  return;
                }
                Navigator.pop(context, email);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
              ),
              child: const Text('ОТПРАВИТЬ КОД'),
            ),
          ],
        );
      },
    ).then((email) {
      emailController.dispose();
      
      if (email != null && email is String && email.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
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
    });
  }
}