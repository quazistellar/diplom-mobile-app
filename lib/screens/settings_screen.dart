import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/course_provider.dart';
import '../providers/user_course_provider.dart';
import '../widgets/setting_item.dart';
import '../utils/snackbar_helper.dart';
import 'base_navigation_screen.dart';

class SettingsScreen extends BaseNavigationScreen {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends BaseNavigationScreenState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _isChangingPassword = false;

  @override
  Widget buildContent(BuildContext context) {
    final themeManager = context.watch<ThemeManager>();
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final theme = themeManager.currentTheme;

    return Column(
      children: [
        AppBar(
          backgroundColor: theme.appBarTheme.backgroundColor,
          elevation: theme.appBarTheme.elevation ?? 4,
          title: Text(
            'Настройки',
            style: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildProfileCard(user, theme, authProvider),
                const SizedBox(height: 24),
                _buildAppearanceSection(themeManager),
                const SizedBox(height: 24),
                // _buildAppSection(themeManager),
                const SizedBox(height: 24),
                _buildAccountSection(themeManager, authProvider),
                const SizedBox(height: 24),
                _buildVersionInfo(theme),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(
      dynamic user, ThemeData theme, AuthProvider authProvider) {
    String userName = 'Иван Иванов';
    String userEmail = 'ivan@example.com';

    if (user != null) {
      final firstName = user.firstName ?? '';
      final lastName = user.lastName ?? '';
      final email = user.email ?? '';

      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        userName = '$firstName $lastName'.trim();
      }
      if (email.isNotEmpty) {
        userEmail = email;
      }
    }

    return Card(
      color: theme.cardTheme.color,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: theme.colorScheme.primary,
                  child: const Icon(Icons.person, size: 32, color: Colors.white),
                ),
                const SizedBox(height: 8),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(userEmail, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.primary, width: 1),
                    ),
                    child: Text(
                      'Слушатель курсов',
                      style: theme.textTheme.labelSmall!.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
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

  Widget _buildAppearanceSection(ThemeManager themeManager) {
    final theme = themeManager.currentTheme;
    final isDark = themeManager.themeMode == ThemeMode.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Внешний вид',
          style: theme.textTheme.bodySmall!.copyWith(
            fontWeight: FontWeight.w900,
            color: theme.hintColor,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: theme.cardTheme.color,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              SettingItem(
                icon: Icons.palette,
                title: 'Тема',
                iconColor: theme.colorScheme.onSurface,
                textColor: theme.colorScheme.onSurface,
                trailing: IconButton(
                  icon: Icon(
                    isDark ? Icons.dark_mode : Icons.light_mode,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  tooltip: isDark ? 'Светлая тема' : 'Тёмная тема',
                  onPressed: () => themeManager.toggleTheme(),
                ),
              ),
              const Divider(height: 1, indent: 56),
              SettingItem(
                icon: Icons.text_fields,
                title: 'Размер шрифта',
                iconColor: theme.colorScheme.onSurface,
                textColor: theme.colorScheme.onSurface,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _getFontSizeIcon(themeManager.fontSize),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant, size: 20),
                  ],
                ),
                onTap: () => _showFontSizeDialog(themeManager),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Widget _buildAppSection(ThemeManager themeManager) {
  //   final theme = themeManager.currentTheme;

  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(
  //         'Приложение',
  //         style: theme.textTheme.bodySmall!.copyWith(
  //           fontWeight: FontWeight.w900,
  //           color: theme.hintColor,
  //           letterSpacing: 0.5,
  //         ),
  //       ),
  //       const SizedBox(height: 12),
  //       Card(
  //         color: theme.cardTheme.color,
  //         elevation: 4,
  //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //         child: Column(
  //           children: [
  //             SettingItem(
  //               icon: Icons.notifications,
  //               title: 'Уведомления',
  //               iconColor: theme.colorScheme.onSurface,
  //               textColor: theme.colorScheme.onSurface,
  //               trailing: Switch(
  //                 value: _notificationsEnabled,
  //                 onChanged: (value) => setState(() => _notificationsEnabled = value),
  //                 activeColor: theme.colorScheme.primary,
  //                 inactiveTrackColor: theme.dividerTheme.color ?? Colors.grey[300],
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildAccountSection(ThemeManager themeManager, AuthProvider authProvider) {
    final theme = themeManager.currentTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Аккаунт',
          style: theme.textTheme.bodySmall!.copyWith(
            fontWeight: FontWeight.w900,
            color: theme.hintColor,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: theme.cardTheme.color,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              SettingItem(
                icon: Icons.edit,
                title: 'Редактировать профиль',
                iconColor: theme.colorScheme.onSurface,
                textColor: theme.colorScheme.onSurface,
                onTap: () => _showEditProfileDialog(context, theme, authProvider),
              ),
              const Divider(height: 1, indent: 56),
              SettingItem(
                icon: Icons.lock,
                title: 'Сменить пароль',
                iconColor: theme.colorScheme.onSurface,
                textColor: theme.colorScheme.onSurface,
                trailing: _isChangingPassword
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                        ),
                      )
                    : null,
                onTap: _isChangingPassword ? null : () => _showChangePasswordDialog(context, theme, authProvider),
              ),
              const Divider(height: 1, indent: 56),
              SettingItem(
                icon: Icons.logout,
                title: 'Выйти',
                textColor: theme.colorScheme.secondary,
                iconColor: theme.colorScheme.secondary,
                onTap: () => _logout(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVersionInfo(ThemeData theme) {
    return Center(
      child: Text(
        'Версия 1.0.0',
        style: theme.textTheme.bodySmall!.copyWith(color: theme.hintColor),
      ),
    );
  }

  Widget _getFontSizeIcon(String fontSize) {
    switch (fontSize) {
      case 'Мелкий':
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.text_format, size: 16),
            Icon(Icons.text_format, size: 14),
            Icon(Icons.text_format, size: 12),
          ],
        );
      case 'Крупный':
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.text_format, size: 20),
            Icon(Icons.text_format, size: 18),
            Icon(Icons.text_format, size: 16),
          ],
        );
      case 'Стандартный':
      default:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.text_format, size: 18),
            Icon(Icons.text_format, size: 16),
            Icon(Icons.text_format, size: 14),
          ],
        );
    }
  }

  void _showFontSizeDialog(ThemeManager themeManager) {
    final theme = themeManager.currentTheme;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.dialogTheme.backgroundColor,
          title: Text(
            'Размер шрифта',
            style: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFontSizeOption(
                context: context,
                theme: theme,
                icon: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.text_format, size: 16),
                    Icon(Icons.text_format, size: 14),
                    Icon(Icons.text_format, size: 12),
                  ],
                ),
                title: 'Мелкий',
                description: 'Для экономии места',
                isSelected: themeManager.fontSize == 'Мелкий',
                onTap: () {
                  themeManager.setFontSize('Мелкий');
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              _buildFontSizeOption(
                context: context,
                theme: theme,
                icon: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.text_format, size: 18),
                    Icon(Icons.text_format, size: 16),
                    Icon(Icons.text_format, size: 14),
                  ],
                ),
                title: 'Стандартный',
                description: 'Рекомендуемый размер',
                isSelected: themeManager.fontSize == 'Стандартный',
                onTap: () {
                  themeManager.setFontSize('Стандартный');
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              _buildFontSizeOption(
                context: context,
                theme: theme,
                icon: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.text_format, size: 20),
                    Icon(Icons.text_format, size: 18),
                    Icon(Icons.text_format, size: 16),
                  ],
                ),
                title: 'Крупный',
                description: 'Для лучшей читаемости',
                isSelected: themeManager.fontSize == 'Крупный',
                onTap: () {
                  themeManager.setFontSize('Крупный');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFontSizeOption({
    required BuildContext context,
    required ThemeData theme,
    required Widget icon,
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary : theme.dividerTheme.color ?? Colors.transparent,
              width: isSelected ? 2 : 0,
            ),
          ),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                    ),
                  ],
                ),
              ),
              if (isSelected) Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog(
      BuildContext context, ThemeData theme, AuthProvider authProvider) async {
    final user = authProvider.currentUser;
    
    final firstNameController = TextEditingController(text: user?.firstName ?? '');
    final lastNameController = TextEditingController(text: user?.lastName ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final patronymicController = TextEditingController(text: user?.patronymic ?? '');

    final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: theme.dialogTheme.backgroundColor,
              title: Text(
                'Редактировать профиль',
                style: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w900),
              ),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: firstNameController,
                        decoration: InputDecoration(
                          labelText: 'Имя',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Введите имя';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Фамилия',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Введите фамилию';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: patronymicController,
                        decoration: InputDecoration(
                          labelText: 'Отчество',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Введите email';
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Введите корректный email';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Отмена', style: theme.textTheme.bodyLarge!.copyWith(color: theme.hintColor)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      try {
                        await authProvider.updateProfile({
                          'first_name': firstNameController.text.trim(),
                          'last_name': lastNameController.text.trim(),
                          'patronymic': patronymicController.text.trim(),
                          'email': emailController.text.trim(),
                        });
                        
                        if (mounted) {
                          SnackBarHelper.showSuccess(context, 'Профиль успешно обновлен');
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (mounted) {
                          SnackBarHelper.showError(context, 'Ошибка: ${e.toString()}');
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary),
                  child: Text('Сохранить', style: theme.textTheme.labelLarge),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showChangePasswordDialog(
      BuildContext context, ThemeData theme, AuthProvider authProvider) async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
    bool _isOldPasswordVisible = false;
    bool _isNewPasswordVisible = false;
    bool _isConfirmPasswordVisible = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: theme.dialogTheme.backgroundColor,
              title: Text(
                'Сменить пароль',
                style: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w900),
              ),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: oldPasswordController,
                        obscureText: !_isOldPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Старый пароль',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixIcon: IconButton(
                            icon: Icon(_isOldPasswordVisible ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _isOldPasswordVisible = !_isOldPasswordVisible),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Введите старый пароль';
                          if (value.length < 8) return 'Пароль должен быть не менее 8 символов';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: !_isNewPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Новый пароль',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixIcon: IconButton(
                            icon: Icon(_isNewPasswordVisible ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _isNewPasswordVisible = !_isNewPasswordVisible),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Введите новый пароль';
                          if (value.length < 8) return 'Пароль должен быть не менее 8 символов';
                          
                          final hasUppercase = RegExp(r'[A-Z]').hasMatch(value);
                          final hasLowercase = RegExp(r'[a-z]').hasMatch(value);
                          final hasDigits = RegExp(r'[0-9]').hasMatch(value);
                          final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value);
                          
                          if (!hasUppercase || !hasLowercase || !hasDigits || !hasSpecial) {
                            return 'Пароль должен содержать заглавные, строчные буквы, цифры и спецсимволы';
                          }
                          
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: !_isConfirmPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Подтвердите новый пароль',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixIcon: IconButton(
                            icon: Icon(_isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Подтвердите новый пароль';
                          if (value != newPasswordController.text) return 'Введенные пароли не совпадают!';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Пароль должен содержать не менее 8 символов,',
                        style: theme.textTheme.bodySmall!.copyWith(color: theme.hintColor),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'включая хотя бы одну заглавную и строчную буквы,',
                        style: theme.textTheme.bodySmall!.copyWith(color: theme.hintColor),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'а также хотя бы цифру и один специальный символ',
                        style: theme.textTheme.bodySmall!.copyWith(color: theme.hintColor),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Отмена', style: theme.textTheme.bodyLarge!.copyWith(color: theme.hintColor)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final oldPass = oldPasswordController.text.trim();
                      final newPass = newPasswordController.text.trim();
                      
                      if (oldPass == newPass) {
                        SnackBarHelper.showWarning(context, 'Новый пароль должен отличаться от старого');
                        return;
                      }
                      
                      setState(() => _isChangingPassword = true);
                      
                      try {
                        await authProvider.changePassword(oldPass, newPass);
                        
                        if (mounted) {
                          SnackBarHelper.showSuccess(context, 'Пароль успешно изменен');
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (mounted) {
                          SnackBarHelper.showError(context, 'Ошибка: ${e.toString()}');
                        }
                      } finally {
                        setState(() => _isChangingPassword = false);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary),
                  child: _isChangingPassword
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Сменить пароль', style: theme.textTheme.labelLarge),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    final themeManager = Provider.of<ThemeManager>(context, listen: false);
    final theme = themeManager.currentTheme;

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.dialogTheme.backgroundColor,
          title: Text(
            'Выход',
            style: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w900),
          ),
          content: Text('Вы уверены, что хотите выйти?', style: theme.textTheme.bodyLarge),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Отмена', style: theme.textTheme.bodyLarge!.copyWith(color: theme.hintColor)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary),
              child: Text('Выйти', style: theme.textTheme.labelLarge),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      final authProvider = context.read<AuthProvider>();
      final courseProvider = context.read<CourseProvider>();
      final userCourseProvider = context.read<UserCourseProvider>();
      
      try {
        await authProvider.logout();
        courseProvider.clearAllFilters();
        userCourseProvider.clearData();
      } catch (e) {
        debugPrint('Logout error: $e');
      }
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/auth');
      }
    }
  }
}