import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unireax_mobile_diplom/screens/certificate_detail_screen.dart';
import '../../providers/certificate_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/progress_provider.dart';

class CertificateEligibilityScreen extends StatefulWidget {
  final int courseId;
  final String courseName;
  
  const CertificateEligibilityScreen({
    Key? key,
    required this.courseId,
    required this.courseName,
  }) : super(key: key);

  @override
  State<CertificateEligibilityScreen> createState() => _CertificateEligibilityScreenState();
}

class _CertificateEligibilityScreenState extends State<CertificateEligibilityScreen> {
  bool _isLoading = false;
  bool _isIssuing = false;
  Map<String, dynamic>? _eligibilityData;

  @override
  void initState() {
    super.initState();
    _checkEligibility();
  }

  Future<void> _checkEligibility() async {
    setState(() => _isLoading = true);

    try {
      final certificateProvider = Provider.of<CertificateProvider>(
        context, 
        listen: false
      );
      
      final data = await certificateProvider.checkEligibility(widget.courseId);
      
      if (mounted) {
        setState(() {
          _eligibilityData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка проверки: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _issueCertificate() async {
    setState(() => _isIssuing = true);

    try {
      final certificateProvider = Provider.of<CertificateProvider>(
        context, 
        listen: false
      );
      
      final result = await certificateProvider.issueCertificate(widget.courseId);
      
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сертификат успешно получен!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      final certificate = result['certificate'] as Map<String, dynamic>;
      
      final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
      await progressProvider.loadEnrolledCourses();
      
      final courseData = {
        'id': widget.courseId,
        'course_name': widget.courseName,
        'course_hours': 0, 
      };

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CertificateDetailScreen(
              certificate: certificate,
              course: courseData,
            ),
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isIssuing = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ошибка получения сертификата: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final theme = themeManager.currentTheme;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: theme.appBarTheme.elevation ?? 4,
        title: Text(
          'Получение сертификата',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Проверка возможности получения сертификата...',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : _eligibilityData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Не удалось проверить сертификат',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _checkEligibility,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : _buildEligibilityContent(theme),
    );
  }

  Widget _buildEligibilityContent(ThemeData theme) {
    final isEligible = _eligibilityData?['eligible'] == true;
    final progress = _eligibilityData?['progress'] ?? 0.0;
    final hasCertificate = _eligibilityData?['has_certificate'] ?? false;
    final courseHasCertificate = _eligibilityData?['course_has_certificate'] ?? false;
    final courseIsCompleted = _eligibilityData?['course_is_completed'] ?? false;
    final errorMessage = _eligibilityData?['error'];
    
    final progressDetails = _eligibilityData?['progress_details'] as Map<String, dynamic>?;
    final assignmentsDetails = progressDetails?['assignments'] as Map<String, dynamic>?;
    final testsDetails = progressDetails?['tests'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Icon(
                  isEligible ? Icons.verified : Icons.card_membership,
                  size: 80,
                  color: isEligible ? Colors.green : theme.colorScheme.secondary,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.courseName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isEligible
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isEligible ? Icons.check_circle : Icons.info,
                          color: isEligible ? Colors.green : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isEligible
                              ? 'Сертификат доступен!'
                              : hasCertificate
                                  ? 'Сертификат уже получен'
                                  : 'Сертификат недоступен',
                          style: TextStyle(
                            color: isEligible ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  _buildProgressItem(
                    icon: Icons.school,
                    label: 'Прогресс курса',
                    value: '${progress.toStringAsFixed(1)}%',
                    color: progress >= 100 ? Colors.green : Colors.blue,
                    theme: theme,
                  ),

                  const Divider(height: 32),

                  if (assignmentsDetails != null) ...[
                    _buildDetailItem(
                      label: 'Практические задания',
                      completed: assignmentsDetails['completed'] ?? 0,
                      total: assignmentsDetails['total'] ?? 0,
                      percentage: assignmentsDetails['percentage'] ?? 0,
                      theme: theme,
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (testsDetails != null) ...[
                    _buildDetailItem(
                      label: 'Тесты',
                      completed: testsDetails['passed'] ?? 0,
                      total: testsDetails['total'] ?? 0,
                      percentage: testsDetails['percentage'] ?? 0,
                      theme: theme,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Условия получения сертификата:',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildConditionItem(
                    icon: Icons.assignment_turned_in,
                    label: 'Все практические работы',
                    isMet: (assignmentsDetails?['completed'] ?? 0) >= (assignmentsDetails?['total'] ?? 0),
                    theme: theme,
                  ),
                  
                  _buildConditionItem(
                    icon: Icons.quiz,
                    label: 'Все тесты пройдены',
                    isMet: (testsDetails?['passed'] ?? 0) >= (testsDetails?['total'] ?? 0),
                    theme: theme,
                  ),
                  
                  _buildConditionItem(
                    icon: Icons.card_membership,
                    label: 'Курс предусматривает сертификат',
                    isMet: courseHasCertificate,
                    theme: theme,
                  ),
                  
                  _buildConditionItem(
                    icon: Icons.done_all,
                    label: 'Курс полностью готов',
                    isMet: courseIsCompleted,
                    theme: theme,
                  ),
                  
                  _buildConditionItem(
                    icon: Icons.verified,
                    label: 'Сертификат еще не получен',
                    isMet: !hasCertificate,
                    theme: theme,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          if (isEligible)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isIssuing ? null : _issueCertificate,
                icon: _isIssuing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.card_membership),
                label: Text(
                  _isIssuing
                      ? 'Получение сертификата...'
                      : 'Получить сертификат',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          
          if (!isEligible && !hasCertificate)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/course/${widget.courseId}',
                  );
                },
                icon: const Icon(Icons.school),
                label: const Text('Продолжить обучение'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

          if (hasCertificate)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Вернуться к результатам'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

          if (errorMessage != null && !isEligible) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      errorMessage,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem({
    required String label,
    required int completed,
    required int total,
    required double percentage,
    required ThemeData theme,
  }) {
    final isComplete = total > 0 && completed >= total;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              isComplete ? '✅ Завершено' : '⏳ В процессе',
              style: TextStyle(
                color: isComplete ? Colors.green : Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total > 0 ? completed / total : 0,
                  backgroundColor: theme.colorScheme.surface,
                  color: isComplete ? Colors.green : theme.primaryColor,
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$completed/$total (${percentage.toStringAsFixed(1)}%)',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConditionItem({
    required IconData icon,
    required String label,
    required bool isMet,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isMet ? Colors.green : theme.colorScheme.secondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isMet ? Colors.green : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}