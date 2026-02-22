import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/progress_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_course_provider.dart';
import '../models/progress.dart';
import '../utils/snackbar_helper.dart';
import 'course_materials_screen.dart';
import 'base_navigation_screen.dart';

class ProgressScreen extends BaseNavigationScreen {
  const ProgressScreen({Key? key}) : super(key: key);

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends BaseNavigationScreenState<ProgressScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!authProvider.isAuthenticated) {
      return;
    }
    
    try {
      await progressProvider.loadEnrolledCourses();
    } catch (e) {
      SnackBarHelper.showError(context, e.toString());
    }
  }

  Future<void> _showLeaveCourseDialog(BuildContext context, CourseProgress course) async {
    final theme = Theme.of(context);
    final userCourseProvider = Provider.of<UserCourseProvider>(context, listen: false);
    
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Покинуть курс'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Вы уверены, что хотите покинуть курс?'),
            const SizedBox(height: 12),
            Text(
              '"${course.courseName}"',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Весь ваш прогресс будет сохранен, но вы больше не сможете получать уведомления.',
              style: TextStyle(
                fontSize: 12,
                color: theme.hintColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Покинуть'),
          ),
        ],
      ),
    );

    if (shouldLeave == true && mounted) {
      try {
        await userCourseProvider.leaveCourse(course.courseId);
        
        if (mounted) {
          SnackBarHelper.showSuccess(
            context,
            'Вы успешно покинули курс',
          );
          await _loadData();
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(
            context,
            e.toString().replaceAll('Exception: ', ''),
          );
        }
      }
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final theme = themeManager.currentTheme;
    final progressProvider = Provider.of<ProgressProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Column(
      children: [
        AppBar(
          backgroundColor: theme.appBarTheme.backgroundColor,
          elevation: theme.appBarTheme.elevation ?? 4,
          title: Row(
            children: [
              Icon(Icons.timeline, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Мой прогресс',
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
              icon: Icon(Icons.refresh, color: theme.colorScheme.onSurface),
              onPressed: _loadData,
              tooltip: 'Обновить',
            ),
          ],
        ),
        Expanded(
          child: _buildBody(theme, progressProvider, authProvider),
        ),
      ],
    );
  }

  Widget _buildBody(ThemeData theme, ProgressProvider progressProvider, AuthProvider authProvider) {
    if (!authProvider.isAuthenticated) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber, size: 64, color: theme.colorScheme.secondary),
            const SizedBox(height: 16),
            Text('Требуется авторизация', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Войдите в систему чтобы увидеть свой прогресс',
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

    if (progressProvider.isLoading && progressProvider.enrolledCourses.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }

    if (progressProvider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Ошибка загрузки', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              progressProvider.errorMessage!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _loadData, child: const Text('Повторить')),
          ],
        ),
      );
    }

    if (progressProvider.enrolledCourses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 80, color: theme.colorScheme.secondary),
            const SizedBox(height: 16),
            Text('Вы еще не записаны на курсы', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Найдите интересный курс и начните обучение',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => handleNavigationTap(1, context),
              child: const Text('Перейти в каталог'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: theme.colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: progressProvider.enrolledCourses.length,
        itemBuilder: (context, index) {
          final course = progressProvider.enrolledCourses[index];
          return _buildCourseCard(course, theme);
        },
      ),
    );
  }

  Widget _buildCourseCard(CourseProgress course, ThemeData theme) {
    final progress = course.progress;
    final isCompleted = course.isCompleted;
    final courseId = course.courseId;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    course.courseName,
                    style: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w900),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Завершен',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            if (course.courseDescription != null && course.courseDescription!.isNotEmpty)
              Text(
                course.courseDescription!,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            
            const SizedBox(height: 16),

            Row(
              children: [
                _buildProgressCircle(progress, theme),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Прогресс: ${progress.toStringAsFixed(1)}%',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: progress / 100,
                        backgroundColor: theme.colorScheme.surface,
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (course.category != null)
                  _buildDetailChip(
                    icon: Icons.category_outlined,
                    text: course.category!,
                    theme: theme,
                  ),
                if (course.hours != null)
                  _buildDetailChip(
                    icon: Icons.access_time_outlined,
                    text: '${course.hours} ч.',
                    theme: theme,
                  ),
                if (course.hasCertificate)
                  _buildDetailChip(
                    icon: Icons.card_membership_outlined,
                    text: 'Сертификат',
                    theme: theme,
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: courseId != 0 ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CourseMaterialsScreen(courseId: courseId),
                        ),
                      );
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_outlined, size: 20),
                        SizedBox(width: 8),
                        Text('Продолжить'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: IconButton(
                    onPressed: () => _showLeaveCourseDialog(context, course),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(Icons.exit_to_app, color: Colors.red),
                    tooltip: 'Покинуть курс',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCircle(double progress, ThemeData theme) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            value: progress / 100,
            strokeWidth: 6,
            backgroundColor: theme.colorScheme.surface,
            color: theme.primaryColor,
          ),
        ),
        Text(
          '${progress.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String text,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.secondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary),
          ),
        ],
      ),
    );
  }
}