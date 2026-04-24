import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/favorite_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_course_provider.dart';
import '../services/api_client.dart';
import '../models/favorite.dart';
import 'course_detail_screen.dart';
import '../utils/snackbar_helper.dart';

/// экран избранных курсов
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _loadFavorites();
      _isInitialized = true;
    }
  }

  /// данная функция загружает список избранных курсов
  Future<void> _loadFavorites() async {
    final favoriteProvider = Provider.of<FavoriteProvider>(context, listen: false);
    await favoriteProvider.loadFavorites();
  }

  /// данная функция удаляет курс из избранного
  Future<void> _removeFavorite(int courseId, String courseName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить из избранного'),
        content: Text('Вы уверены, что хотите удалить курс "$courseName" из избранного?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final favoriteProvider = Provider.of<FavoriteProvider>(context, listen: false);
      final success = await favoriteProvider.removeFavorite(courseId);
      if (mounted && success) {
        SnackBarHelper.showSuccess(context, 'Курс удалён из избранного');
      } else if (mounted) {
        SnackBarHelper.showError(context, 'Ошибка при удалении');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final favoriteProvider = Provider.of<FavoriteProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    if (!authProvider.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Избранное'),
          backgroundColor: theme.appBarTheme.backgroundColor,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_border, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Войдите в аккаунт',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                'Чтобы добавлять курсы в избранное',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/auth');
                },
                child: const Text('Войти'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Избранное'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        actions: [
          if (favoriteProvider.favoritesCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${favoriteProvider.favoritesCount}',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadFavorites,
        child: _buildBody(theme, favoriteProvider),
      ),
    );
  }

  /// данная функция создает тело экрана
  Widget _buildBody(ThemeData theme, FavoriteProvider provider) {
    if (provider.isLoading && provider.favorites.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              provider.errorMessage!,
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFavorites,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (provider.favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Избранное пусто',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Добавляйте курсы, чтобы не потерять их',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/courses');
              },
              icon: const Icon(Icons.search),
              label: const Text('Перейти к курсам'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: provider.favorites.length,
      itemBuilder: (context, index) {
        final favorite = provider.favorites[index];
        return _buildFavoriteCard(theme, favorite);
      },
    );
  }

  /// данная функция создает карточку избранного курса
  Widget _buildFavoriteCard(ThemeData theme, FavoriteCourse favorite) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(child: CircularProgressIndicator()),
          );

          try {
            final userCourseProvider = Provider.of<UserCourseProvider>(context, listen: false);
            await userCourseProvider.loadUserCourses();
            
            final courseData = await _apiClient.get<Map<String, dynamic>>(
              '/courses/${favorite.id}/',
              isPublic: true,
            );

            if (!mounted) return;
            Navigator.pop(context);

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CourseDetailScreen(
                  courseId: favorite.id,
                  courseData: courseData,
                ),
              ),
            );
          } catch (e) {
            if (!mounted) return;
            Navigator.pop(context);
            SnackBarHelper.showError(
              context, 
              'Ошибка загрузки данных курса: ${e.toString().replaceFirst('Exception: ', '')}'
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: favorite.photoPath != null && favorite.photoPath!.isNotEmpty
                    ? Image.network(
                        _apiClient.getImageUrl(favorite.photoPath),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.school, size: 40, color: Colors.grey),
                          );
                        },
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.school, size: 40, color: Colors.grey),
                      ),
              ),
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      favorite.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    if (favorite.categoryName != null)
                      Text(
                        favorite.categoryName!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.primaryColor,
                        ),
                      ),
                    
                    const SizedBox(height: 4),
                    
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 2),
                            Text(
                              '${favorite.hours} ч',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 2),
                            Text(
                              '${favorite.studentCount}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              favorite.avgRating.toStringAsFixed(1),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          favorite.isFree ? 'Бесплатно' : '${favorite.price} ₽',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: favorite.isFree ? Colors.green : theme.primaryColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.favorite, color: Colors.red),
                          onPressed: () => _removeFavorite(favorite.id, favorite.name),
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}