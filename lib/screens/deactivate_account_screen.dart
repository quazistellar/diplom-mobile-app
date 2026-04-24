import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/favorite_provider.dart';
import '../services/api_client.dart';
import '../utils/snackbar_helper.dart';

/// экран деактивации аккаунта
class DeactivateAccountScreen extends StatefulWidget {
  const DeactivateAccountScreen({super.key});

  @override
  State<DeactivateAccountScreen> createState() => _DeactivateAccountScreenState();
}

class _DeactivateAccountScreenState extends State<DeactivateAccountScreen> {
  final ApiClient _apiClient = ApiClient();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _isConfirmed = false;
  Map<String, dynamic>? _deactivateInfo;
  
  @override
  void initState() {
    super.initState();
    _loadDeactivateInfo();
  }
  
  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }
  
  Future<void> _loadDeactivateInfo() async {
    setState(() => _isLoading = true);
    
    try {
      final info = await _apiClient.getDeactivateInfo();
      setState(() {
        _deactivateInfo = info;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      SnackBarHelper.showError(context, 'Ошибка загрузки информации: $e');
    }
  }
   
  /// функция деактивации аккаунта
  Future<void> _deactivateAccount() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isConfirmed) {
      SnackBarHelper.showWarning(context, 'Подтвердите деактивацию аккаунта');
      return;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Деактивация аккаунта'),
        content: const Text(
          'Вы уверены, что хотите деактивировать аккаунт?\n\n'
          'Это действие нельзя отменить. Все ваши данные будут анонимизированы.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Деактивировать'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() => _isLoading = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      final result = await _apiClient.deactivateAccount(
        _passwordController.text,
      );
      
      if (result['success'] == true) {
        await authProvider.logout();
        Provider.of<FavoriteProvider>(context, listen: false).clearData();
        
        if (mounted) {
          SnackBarHelper.showSuccess(context, result['detail'] ?? 'Аккаунт деактивирован');
          Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
        }
      } else {
        throw Exception(result['detail'] ?? 'Ошибка деактивации');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Деактивация аккаунта'),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.red.shade700, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Внимание! Это действие необратимо.',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  if (_deactivateInfo != null) ...[
                    Text(
                      'Будут удалены или анонимизированы:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    _buildInfoRow(
                      icon: Icons.school,
                      label: 'Активных курсов',
                      value: '${_deactivateInfo!['active_courses_count'] ?? 0}',
                      theme: theme,
                    ),
                    _buildInfoRow(
                      icon: Icons.favorite,
                      label: 'Избранных курсов',
                      value: '${_deactivateInfo!['favorites_count'] ?? 0}',
                      theme: theme,
                    ),
                    _buildInfoRow(
                      icon: Icons.star,
                      label: 'Отзывов',
                      value: '${_deactivateInfo!['reviews_count'] ?? 0}',
                      theme: theme,
                    ),
                    _buildInfoRow(
                      icon: Icons.assignment,
                      label: 'Выполненных заданий',
                      value: '${_deactivateInfo!['assignments_count'] ?? 0}',
                      theme: theme,
                    ),
                    _buildInfoRow(
                      icon: Icons.quiz,
                      label: 'Пройденных тестов',
                      value: '${_deactivateInfo!['test_results_count'] ?? 0}',
                      theme: theme,
                    ),
                    if (_deactivateInfo!['has_certificate'] == true)
                      _buildInfoRow(
                        icon: Icons.star,
                        label: 'Сертификаты',
                        value: 'Будут удалены',
                        theme: theme,
                        valueColor: Colors.red,
                      ),
                    
                    const SizedBox(height: 24),
                    
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Email: ${_deactivateInfo!['email']}',
                            style: TextStyle(color: theme.hintColor, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Username: ${_deactivateInfo!['username']}',
                            style: TextStyle(color: theme.hintColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Введите пароль для подтверждения',
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Введите пароль';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        CheckboxListTile(
                          value: _isConfirmed,
                          onChanged: (value) {
                            setState(() {
                              _isConfirmed = value ?? false;
                            });
                          },
                          title: const Text('Я понимаю, что это действие нельзя отменить'),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: Colors.red,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _deactivateAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Деактивировать аккаунт',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}