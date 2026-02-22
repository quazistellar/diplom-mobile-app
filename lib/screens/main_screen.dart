import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unireax_mobile_diplom/models/course.dart';
import 'package:unireax_mobile_diplom/models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/course_provider.dart';
import '../providers/statistics_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/course_card.dart';
import '../screens/course_detail_screen.dart';
import '../screens/base_navigation_screen.dart';
import '../utils/formatters.dart';

class MainScreen extends BaseNavigationScreen {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends BaseNavigationScreenState<MainScreen> {
  final _searchController = TextEditingController();
  bool _isLoading = false;
  String _searchQuery = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      final courseProvider = context.read<CourseProvider>();
      final statsProvider = context.read<StatisticsProvider>();
      
      await Future.wait([
        courseProvider.fetchCourses(),
        statsProvider.loadStatistics(),
        courseProvider.loadCourseCategories(),
        courseProvider.loadCourseTypes(),
      ]);
      
      if (context.read<AuthProvider>().isAuthenticated) {
        await courseProvider.loadUserCourses();
      }
      
    } catch (e) {
      print('Ошибка загрузки: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);

    try {
      final courseProvider = context.read<CourseProvider>();
      final statsProvider = context.read<StatisticsProvider>();
      
      await Future.wait([
        courseProvider.fetchCourses(),
        statsProvider.loadStatistics(),
      ]);
      
      if (context.read<AuthProvider>().isAuthenticated) {
        await courseProvider.loadUserCourses();
      }
      
      _showSuccess('Данные обновлены');
    } catch (e) {
      _showError('Ошибка обновления данных');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (_searchQuery != value) {
        setState(() => _searchQuery = value);
      }
    });
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    final themeManager = context.watch<ThemeManager>();
    final theme = themeManager.currentTheme;
    final authProvider = context.watch<AuthProvider>();
    final courseProvider = context.watch<CourseProvider>();
    final statsProvider = context.watch<StatisticsProvider>();
    
    final user = authProvider.currentUser;
    final allCourses = courseProvider.allCourses;

    final displayedCourses = _searchQuery.isEmpty 
        ? allCourses.take(6).toList()
        : allCourses.where((course) => 
            course.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (course.category?.name.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
          ).toList();

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: theme.appBarTheme.elevation ?? 4,
        title: Row(
          children: [
            Icon(Icons.home, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Главная',
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
            onPressed: _refreshData,
            tooltip: 'Обновить',
          ),
          _buildUserAvatar(user, theme, authProvider),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: theme.colorScheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGreeting(user, theme),
              const SizedBox(height: 24),
              
              _buildSearch(theme),
              const SizedBox(height: 24),
              
              _buildStats(statsProvider, theme),
              const SizedBox(height: 32),
              
              _buildCoursesHeader(displayedCourses.length, theme),
              const SizedBox(height: 16),
              
              _buildCoursesList(displayedCourses, courseProvider, theme),
              const SizedBox(height: 20),
              
              if (_searchQuery.isEmpty && allCourses.length > 6)
                _buildViewAllButton(theme),
              
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(User? user, ThemeData theme, AuthProvider authProvider) {
    return PopupMenuButton<String>(
      icon: CircleAvatar(
        backgroundColor: theme.colorScheme.primary,
        child: user != null
            ? Text(
                user.initials,
                style: const TextStyle(color: Colors.white),
              )
            : const Icon(Icons.person, color: Colors.white, size: 20),
      ),
      onSelected: (value) {
        if (value == 'profile') {
          Navigator.pushNamed(context, '/profile');
        } else if (value == 'settings') {
          handleNavigationTap(4, context);
        } else if (value == 'logout') {
          _showLogoutDialog(context, authProvider, theme);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person, size: 20),
              SizedBox(width: 8),
              Text('Профиль'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 20),
              SizedBox(width: 8),
              Text('Выйти'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGreeting(User? user, ThemeData theme) {
    String greeting = _getGreetingText(user);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Выберите курс, начните или продолжите своё обучение',
          style: TextStyle(
            fontSize: 14,
            color: theme.hintColor,
          ),
        ),
      ],
    );
  }

  String _getGreetingText(User? user) {
    if (user != null) {
      return 'Добро пожаловать, ${user.fullName}!';
    }
    return 'Добро пожаловать!';
  }

  Widget _buildSearch(ThemeData theme) {
    return Card(
      color: theme.cardTheme.color,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.search, color: theme.hintColor),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Поиск курсов...',
                  hintStyle: TextStyle(color: theme.hintColor),
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: TextStyle(color: theme.colorScheme.onSurface),
                onChanged: _onSearchChanged,
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: Icon(Icons.clear, size: 20, color: theme.hintColor),
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(StatisticsProvider statsProvider, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'UNIREAX в цифрах',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildStatCard(
                icon: Icons.people,
                value: Formatters.formatNumber(statsProvider.getTotalUsers()),
                label: 'пользователей платформы',
                theme: theme,
              ),
              _buildStatCard(
                icon: Icons.book,
                value: Formatters.formatNumber(statsProvider.getTotalCourses()),
                label: 'курсов',
                theme: theme,
              ),
              _buildStatCard(
                icon: Icons.star,
                value: statsProvider.getAverageRating().toStringAsFixed(1),
                label: 'средняя оценка',
                theme: theme,
              ),
              _buildStatCard(
                icon: Icons.school,
                value: Formatters.formatNumber(statsProvider.getActiveUsers()),
                label: 'активных слушателей',
                theme: theme,
              ),
              if (context.read<AuthProvider>().isAuthenticated) ...[
                _buildStatCard(
                  icon: Icons.timeline,
                  value: context.read<CourseProvider>().getActiveCoursesCount().toString(),
                  label: 'ваших активных курсов',
                  theme: theme,
                ),
                _buildStatCard(
                  icon: Icons.done_all,
                  value: context.read<CourseProvider>().getCompletedCoursesCount().toString(),
                  label: 'ваших завершенных курсов',
                  theme: theme,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required ThemeData theme,
  }) {
    return SizedBox(
      width: 110,
      child: Card(
        color: theme.cardTheme.color,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: theme.primaryColor, size: 24),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.hintColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.visible,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoursesHeader(int count, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _searchQuery.isEmpty ? 'Популярные курсы' : 'Результаты поиска по курсам',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
          ),
        ),
        Text(
          '$count ${Formatters.getCourseWord(count)}',
          style: TextStyle(
            color: theme.hintColor,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildCoursesList(List<Course> courses, CourseProvider courseProvider, ThemeData theme) {
    if (courses.isEmpty) {
      return _buildEmptyCoursesState(theme);
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: courses.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final course = courses[index];
        
        return CourseCard(
          course: course.copyWith(
            isEnrolled: courseProvider.isUserEnrolled(course.id),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CourseDetailScreen(
                  courseId: course.id,
                  courseData: course.rawData,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyCoursesState(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 40),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            _searchQuery.isNotEmpty ? Icons.search_off : Icons.school,
            color: theme.hintColor,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty 
                ? 'По вашему запросу "$_searchQuery" курсы не были найдены'
                : 'Курсы в данный момент недоступны',
            style: TextStyle(
              color: theme.hintColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
                child: Text(
                  'Очистить поиск',
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildViewAllButton(ThemeData theme) {
    return Center(
      child: ElevatedButton(
        onPressed: () => handleNavigationTap(1, context),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Все курсы'),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: 18),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.dialogTheme.backgroundColor,
          title: Text(
            'Выход',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'Вы уверены, что хотите выйти?',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Отмена',
                style: TextStyle(color: theme.hintColor),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await authProvider.logout();
                if (mounted) {
                  context.read<CourseProvider>().clearAllFilters();
                  Navigator.pushReplacementNamed(context, '/auth');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
              ),
              child: const Text('Выйти'),
            ),
          ],
        );
      },
    );
  }
}

extension on Course {
  Course copyWith({bool? isEnrolled}) {
    return Course(
      id: id,
      name: name,
      description: description,
      price: price,
      hours: hours,
      hasCertificate: hasCertificate,
      maxPlaces: maxPlaces,
      rating: rating,
      photoPath: photoPath,
      category: category,
      type: type,
      isActive: isActive,
      isCompleted: isCompleted,
      isEnrolled: isEnrolled ?? this.isEnrolled,
      rawData: rawData,
    );
  }
}