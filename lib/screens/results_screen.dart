import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/progress_provider.dart';
import '../providers/certificate_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../models/certificate.dart';
import '../models/progress.dart';
import '../utils/snackbar_helper.dart';
import 'base_navigation_screen.dart';
import 'certificate_detail_screen.dart';

class ResultsScreen extends BaseNavigationScreen {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends BaseNavigationScreenState<ResultsScreen> {
  bool _isCheckingCertificates = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
    final certificateProvider = Provider.of<CertificateProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated) {
      return;
    }

    try {
      await Future.wait([
        progressProvider.loadResults(),
        certificateProvider.loadCertificates(),
      ]);
    } catch (e) {
      SnackBarHelper.showError(context, 'Ошибка загрузки данных: $e');
    }
  }

  Future<void> _checkAllCertificates() async {
    setState(() => _isCheckingCertificates = true);

    try {
      final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
      final certificateProvider = Provider.of<CertificateProvider>(context, listen: false);
      
      final stats = progressProvider.courseStats;
      final completedCourses = stats?.completedCourses ?? 0;
      
      if (completedCourses == 0) {
        SnackBarHelper.showInfo(context, 'У вас пока нет завершенных курсов');
        setState(() => _isCheckingCertificates = false);
        return;
      }

      await progressProvider.loadEnrolledCourses();
      final courses = progressProvider.enrolledCourses;
      
      int issuedCount = 0;
      List<String> issuedCourses = [];

      for (var course in courses) {
        final courseId = course.courseId;
        final courseName = course.courseName;
        final isCompleted = course.isCompleted;
        
        if (isCompleted) {
          try {
            final eligibility = await certificateProvider.checkEligibility(courseId);
            
            if (eligibility['eligible'] == true) {
              await certificateProvider.issueCertificate(courseId);
              issuedCount++;
              issuedCourses.add(courseName);
            }
          } catch (e) {
            print('Ошибка проверки курса $courseId: $e');
          }
        }
      }

      await Future.wait([
        progressProvider.loadResults(),
        certificateProvider.loadCertificates(),
      ]);

      if (issuedCount > 0) {
        SnackBarHelper.showSuccess(
          context,
          'Получено сертификатов: $issuedCount\n'
          '${issuedCourses.take(3).join('\n')}${issuedCourses.length > 3 ? '\n...' : ''}'
        );
      } else {
        SnackBarHelper.showInfo(context, 'Нет доступных сертификатов для получения');
      }

    } catch (e) {
      SnackBarHelper.showError(context, 'Ошибка проверки сертификатов: $e');
    } finally {
      setState(() => _isCheckingCertificates = false);
    }
  }

  Future<void> _downloadCertificate(int certificateId) async {
    if (!mounted) return;

    final certificateProvider = Provider.of<CertificateProvider>(context, listen: false);

    try {
      final filePath = await certificateProvider.downloadCertificate(certificateId);
      if (!mounted) return;
      
      _showDownloadSuccessDialog(filePath);
      
    } catch (e) {
      SnackBarHelper.showError(context, 'Ошибка скачивания: $e');
    }
  }

  void _showDownloadSuccessDialog(String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Сертификат сохранен'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Файл сохранен в папку:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                filePath,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final certificateProvider = Provider.of<CertificateProvider>(
                context, 
                listen: false
              );
              await certificateProvider.openCertificate(filePath);
            },
            child: const Text('Открыть'),
          ),
        ],
      ),
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final theme = themeManager.currentTheme;
    final progressProvider = Provider.of<ProgressProvider>(context);
    final certificateProvider = Provider.of<CertificateProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.colorScheme.background,
        appBar: AppBar(
          backgroundColor: theme.appBarTheme.backgroundColor,
          elevation: theme.appBarTheme.elevation ?? 4,
          title: Row(
            children: [
              Icon(Icons.card_membership, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Мои результаты',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: _isCheckingCertificates
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.verified_user),
              onPressed: _isCheckingCertificates ? null : _checkAllCertificates,
              tooltip: 'Проверить доступные сертификаты',
            ),
            IconButton(
              icon: Icon(Icons.refresh, color: theme.colorScheme.onSurface),
              onPressed: _loadData,
              tooltip: 'Обновить',
            ),
          ],
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Статистика'),
              Tab(text: 'Сертификаты'),
            ],
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.hintColor,
            indicatorColor: theme.colorScheme.primary,
          ),
        ),
        body: TabBarView(
          children: [
            _buildStatisticsTab(theme, progressProvider, authProvider),
            _buildCertificatesTab(theme, progressProvider, certificateProvider, authProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsTab(
    ThemeData theme,
    ProgressProvider progressProvider,
    AuthProvider authProvider,
  ) {
    if (!authProvider.isAuthenticated) {
      return _buildAuthRequired(theme);
    }

    if (progressProvider.isLoading && progressProvider.courseStats == null) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }

    if (progressProvider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Ошибка загрузки', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(progressProvider.errorMessage!, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _loadData, child: const Text('Повторить')),
          ],
        ),
      );
    }

    final stats = progressProvider.courseStats;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Общая статистика',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900) ??
                        const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 20),
                  _buildStatItem(
                    icon: Icons.school_outlined,
                    label: 'Всего курсов',
                    value: '${stats?.totalCourses ?? 0}',
                    theme: theme,
                  ),
                  _buildStatItem(
                    icon: Icons.done_all,
                    label: 'Завершено курсов',
                    value: '${stats?.completedCourses ?? 0}',
                    theme: theme,
                  ),
                  _buildStatItem(
                    icon: Icons.percent,
                    label: 'Процент завершения',
                    value: '${(stats?.completionRate as num?)?.toStringAsFixed(1) ?? '0'}%',
                    theme: theme,
                  ),
                  _buildStatItem(
                    icon: Icons.card_membership,
                    label: 'Сертификатов',
                    value: '${stats?.certificatesCount ?? 0}',
                    theme: theme,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.assignment_turned_in, size: 32, color: Colors.green),
                        const SizedBox(height: 12),
                        Text('Задания', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          '${stats?.assignmentsCompleted ?? 0}/${stats?.assignmentsTotal ?? 0}',
                          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900) ??
                              const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                        ),
                        if ((stats?.assignmentsTotal ?? 0) > 0)
                          Text(
                            '${(stats?.assignmentsPercentage as num?)?.toStringAsFixed(1) ?? '0'}%',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.quiz, size: 32, color: Colors.blue),
                        const SizedBox(height: 12),
                        Text('Тесты', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          '${stats?.testsPassed ?? 0}/${stats?.testsTotal ?? 0}',
                          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900) ??
                              const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                        ),
                        if ((stats?.testsTotal ?? 0) > 0)
                          Text(
                            '${(stats?.testsPercentage as num?)?.toStringAsFixed(1) ?? '0'}%',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Прогресс обучения',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900) ??
                        const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: _buildProgressChart(
                      theme,
                      stats?.totalCourses ?? 0,
                      stats?.completedCourses ?? 0,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          if ((stats?.completedCourses ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: _isCheckingCertificates ? null : _checkAllCertificates,
                icon: _isCheckingCertificates
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.verified),
                label: Text(
                  _isCheckingCertificates
                      ? 'Проверка сертификатов...'
                      : 'Проверить доступные сертификаты',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCertificatesTab(
    ThemeData theme,
    ProgressProvider progressProvider,
    CertificateProvider certificateProvider,
    AuthProvider authProvider,
  ) {
    if (!authProvider.isAuthenticated) {
      return _buildAuthRequired(theme);
    }

    if (progressProvider.isLoading && progressProvider.certificates.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }

    if (progressProvider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Ошибка загрузки', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(progressProvider.errorMessage!, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _loadData, child: const Text('Повторить')),
          ],
        ),
      );
    }

    final certificates = progressProvider.certificates;

    if (certificates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.card_membership_outlined, size: 80, color: theme.colorScheme.secondary),
            const SizedBox(height: 16),
            Text('У вас пока нет сертификатов', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Завершите курсы для получения сертификатов',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            ElevatedButton.icon(
              onPressed: _isCheckingCertificates ? null : _checkAllCertificates,
              icon: _isCheckingCertificates
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              label: Text(
                _isCheckingCertificates ? 'Проверка...' : 'Проверить наличие сертификатов',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            
            const SizedBox(height: 12),
            
            OutlinedButton.icon(
              onPressed: () => handleNavigationTap(1, context),
              icon: const Icon(Icons.school),
              label: const Text('Перейти к курсам'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _isCheckingCertificates ? null : _checkAllCertificates,
            icon: _isCheckingCertificates
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.verified),
            label: Text(
              _isCheckingCertificates
                  ? 'Проверка сертификатов...'
                  : 'Проверить новые сертификаты',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: certificates.length,
            itemBuilder: (context, index) {
              final certData = certificates[index];
              final certificate = certData.certificate;
              final course = certData.course;
              final certificateId = certificate.id;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CertificateDetailScreen(
                          certificate: certificate.rawData,
                          course: course?.rawData ?? {},
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified, color: Colors.green, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                course?.name ?? 'Без названия',
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900) ??
                                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCertificateDetail(
                              icon: Icons.numbers,
                              label: 'Номер сертификата',
                              value: certificate.certificateNumber,
                              theme: theme,
                            ),
                            const SizedBox(height: 12),
                            _buildCertificateDetail(
                              icon: Icons.calendar_today,
                              label: 'Дата выдачи',
                              value: certificate.formattedDate,
                              theme: theme,
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        if (certificateId != 0)
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _downloadCertificate(certificateId),
                                  icon: const Icon(Icons.download),
                                  label: const Text('Скачать'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAuthRequired(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber, size: 64, color: theme.colorScheme.secondary),
          const SizedBox(height: 16),
          Text('Требуется авторизация', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Войдите в систему чтобы увидеть свои результаты',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/auth'),
            child: const Text('Войти'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.secondary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900) ??
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateDetail({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary)),
              const SizedBox(height: 2),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressChart(ThemeData theme, int totalCourses, int completedCourses) {
    final completionRate = totalCourses == 0 ? 0.0 : (completedCourses / totalCourses * 100);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: completionRate / 100,
                strokeWidth: 10,
                backgroundColor: theme.colorScheme.surface,
                color: theme.primaryColor,
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${completionRate.toStringAsFixed(1)}%',
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900) ??
                        const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  Text('завершено', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(color: theme.primaryColor, label: 'Завершено ($completedCourses)', theme: theme),
            const SizedBox(width: 16),
            _buildLegendItem(
              color: theme.colorScheme.surface,
              label: 'В процессе (${totalCourses - completedCourses})',
              theme: theme,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}