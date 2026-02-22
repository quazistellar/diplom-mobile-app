import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/course_provider.dart';
import '../providers/user_course_provider.dart';
import '../widgets/course_card.dart';
import '../widgets/filter_chip.dart';
import '../screens/course_detail_screen.dart';
import '../models/course.dart';
import '../utils/snackbar_helper.dart';
import 'base_navigation_screen.dart';

class CoursesScreen extends BaseNavigationScreen {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends BaseNavigationScreenState<CoursesScreen> {
  
  final _searchController = TextEditingController();
  bool _isLoading = false;
  Timer? _searchDebounce;
  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      _syncSearchWithProvider();
    });
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncSearchWithProvider();
      }
    });
  }
  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }
  void _syncSearchWithProvider() {
    if (!mounted) return;
    final courseProvider = Provider.of<CourseProvider>(context, listen: false);
    final currentSearch = courseProvider.currentSearchQuery ?? '';
    if (_searchController.text != currentSearch) {
      _searchController.text = currentSearch;
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchController.text.length),
      );
    }
  }
  Future<void> _loadInitialData() async {
    if (_isLoading || !mounted) return;
    
    setState(() => _isLoading = true);

    try {
      final courseProvider = Provider.of<CourseProvider>(context, listen: false);
      final userCourseProvider = Provider.of<UserCourseProvider>(context, listen: false);
      
      await Future.wait([
        courseProvider.fetchCourses(),
        courseProvider.loadCourseCategories(),
        courseProvider.loadCourseTypes(),
      ]);
      
      if (context.read<AuthProvider>().isAuthenticated) {
        await userCourseProvider.loadUserCourses();
      }
    } catch (e) {
      SnackBarHelper.showError(context, 'Ошибка загрузки курсов');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCourses() async {
    if (_isLoading || !mounted) return;
    
    setState(() => _isLoading = true);

    try {
      final courseProvider = Provider.of<CourseProvider>(context, listen: false);
      await courseProvider.fetchCourses();
    } catch (e) {
      SnackBarHelper.showError(context, 'Ошибка загрузки курсов');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      
      try {
        final courseProvider = Provider.of<CourseProvider>(context, listen: false);
        await courseProvider.updateFilters(
          searchQuery: value.isEmpty ? null : value,
          categoryIds: courseProvider.selectedCategoryIds,
          typeIds: courseProvider.selectedTypeIds,
          hasCertificate: courseProvider.currentHasCertificate,
          freeOnly: courseProvider.currentFreeOnly,
          sortBy: courseProvider.currentSortBy,
          sortOrder: courseProvider.currentSortOrder,
        );
      } catch (e) {
        print('Ошибка поиска: $e');
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchDebounce?.cancel();
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      
      try {
        final courseProvider = Provider.of<CourseProvider>(context, listen: false);
        await courseProvider.updateFilters(
          searchQuery: null,
          categoryIds: courseProvider.selectedCategoryIds,
          typeIds: courseProvider.selectedTypeIds,
          hasCertificate: courseProvider.currentHasCertificate,
          freeOnly: courseProvider.currentFreeOnly,
          sortBy: courseProvider.currentSortBy,
          sortOrder: courseProvider.currentSortOrder,
        );
      } catch (e) {
        print('Ошибка очистки поиска: $e');
      }
    });
  }

  void _resetFilters() async {
    if (!mounted) return;
    
    try {
      final courseProvider = Provider.of<CourseProvider>(context, listen: false);
      await courseProvider.clearAllFilters();
      _clearSearch();
    } catch (e) {
      SnackBarHelper.showError(context, 'Ошибка сброса фильтров');
    }
  }

  Future<void> _clearCategories() async {
    try {
      final courseProvider = Provider.of<CourseProvider>(context, listen: false);
      await courseProvider.clearCategoryFilter();
    } catch (e) {
      SnackBarHelper.showError(context, 'Ошибка сброса категорий');
    }
  }

  Future<void> _clearTypes() async {
    try {
      final courseProvider = Provider.of<CourseProvider>(context, listen: false);
      await courseProvider.clearTypeFilter();
    } catch (e) {
      SnackBarHelper.showError(context, 'Ошибка сброса типов');
    }
  }

  Future<void> _clearCertificate() async {
    try {
      final courseProvider = Provider.of<CourseProvider>(context, listen: false);
      await courseProvider.clearCertificateFilter();
    } catch (e) {
      SnackBarHelper.showError(context, 'Ошибка сброса фильтра сертификатов');
    }
  }

  Future<void> _clearFreeOnly() async {
    try {
      final courseProvider = Provider.of<CourseProvider>(context, listen: false);
      await courseProvider.clearFreeOnlyFilter();
    } catch (e) {
      SnackBarHelper.showError(context, 'Ошибка сброса фильтра бесплатных курсов');
    }
  }

  Future<void> _clearSorting() async {
    try {
      final courseProvider = Provider.of<CourseProvider>(context, listen: false);
      await courseProvider.clearSorting();
    } catch (e) {
      SnackBarHelper.showError(context, 'Ошибка сброса сортировки');
    }
  }

  String _getCategoryNames(CourseProvider courseProvider, List<int> categoryIds) {
    if (categoryIds.isEmpty) return '';
    
    final categories = courseProvider.courseCategories;
    final selectedNames = categoryIds.map((id) {
      final category = categories.firstWhere(
        (cat) => cat.id == id,
        orElse: () => CourseCategory(id: id, name: 'Категория $id'),
      );
      return category.name;
    }).toList();
    
    if (selectedNames.length <= 2) {
      return selectedNames.join(', ');
    } else {
      return '${selectedNames.length} категорий';
    }
  }

  String _getTypeNames(CourseProvider courseProvider, List<int> typeIds) {
    if (typeIds.isEmpty) return '';
    
    final types = courseProvider.courseTypes;
    final selectedNames = typeIds.map((id) {
      final type = types.firstWhere(
        (t) => t.id == id,
        orElse: () => CourseType(id: id, name: 'Тип $id'),
      );
      return type.name;
    }).toList();
    
    if (selectedNames.length <= 2) {
      return selectedNames.join(', ');
    } else {
      return '${selectedNames.length} типов';
    }
  }

  IconData _getTypeIcon(String typeName) {
    final lowerName = typeName.toLowerCase();
    if (lowerName.contains('образовательная программа') || lowerName.contains('online')) {
      return Icons.wifi;
    } else if (lowerName.contains('подготовка к экзаменам') || lowerName.contains('экзамен')) {
      return Icons.book;
    } else if (lowerName.contains('профессиональная переподготовка')) {
      return Icons.school;
    }
    return Icons.school;
  }

  Widget _buildFiltersDialog(BuildContext context, CourseProvider courseProvider) {
    final theme = Theme.of(context);
    final categories = courseProvider.courseCategories;
    final types = courseProvider.courseTypes;
    
    final selectedCategoryIds = List<int>.from(courseProvider.selectedCategoryIds);
    final selectedTypeIds = List<int>.from(courseProvider.selectedTypeIds);
    final currentHasCertificate = courseProvider.currentHasCertificate;
    final currentFreeOnly = courseProvider.currentFreeOnly;
    final currentSortBy = courseProvider.currentSortBy;
    final currentSortOrder = courseProvider.currentSortOrder;
    
    List<int> tempCategoryIds = List<int>.from(selectedCategoryIds);
    List<int> tempTypeIds = List<int>.from(selectedTypeIds);
    bool? hasCertificateFilter = currentHasCertificate;
    bool? freeOnlyFilter = currentFreeOnly;
    String? selectedSortBy = currentSortBy;
    String sortOrder = currentSortOrder;

    return StatefulBuilder(
      builder: (context, setState) {
        return Dialog(
          backgroundColor: theme.cardTheme.color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Фильтры и сортировка',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Сортировка',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            CustomFilterChip(
                              icon: Icons.sort,
                              label: 'По умолчанию',
                              isSelected: selectedSortBy == null,
                              onTap: () {
                                setState(() {
                                  selectedSortBy = null;
                                  sortOrder = 'asc';
                                });
                              },
                            ),
                            CustomFilterChip(
                              icon: Icons.attach_money,
                              label: 'По цене',
                              isSelected: selectedSortBy == 'course_price',
                              onTap: () {
                                setState(() {
                                  selectedSortBy = 'course_price';
                                  if (sortOrder.isEmpty) sortOrder = 'asc';
                                });
                              },
                            ),
                            CustomFilterChip(
                              icon: Icons.timer,
                              label: 'По часам',
                              isSelected: selectedSortBy == 'course_hours',
                              onTap: () {
                                setState(() {
                                  selectedSortBy = 'course_hours';
                                  if (sortOrder.isEmpty) sortOrder = 'asc';
                                });
                              },
                            ),
                            CustomFilterChip(
                              icon: Icons.star,
                              label: 'По рейтингу',
                              isSelected: selectedSortBy == 'rating',
                              onTap: () {
                                setState(() {
                                  selectedSortBy = 'rating';
                                  if (sortOrder.isEmpty) sortOrder = 'asc';
                                });
                              },
                            ),
                          ],
                        ),

                        if (selectedSortBy != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Порядок:',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.arrow_upward, size: 16),
                                    const SizedBox(width: 4),
                                    const Text('По возрастанию'),
                                  ],
                                ),
                                selected: sortOrder == 'asc',
                                onSelected: (selected) {
                                  if (selected) setState(() => sortOrder = 'asc');
                                },
                              ),
                              ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.arrow_downward, size: 16),
                                    const SizedBox(width: 4),
                                    const Text('По убыванию'),
                                  ],
                                ),
                                selected: sortOrder == 'desc',
                                onSelected: (selected) {
                                  if (selected) setState(() => sortOrder = 'desc');
                                },
                              ),
                            ],
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Категории',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      tempCategoryIds = categories
                                          .map((cat) => cat.id)
                                          .toList();
                                    });
                                  },
                                  child: Text(
                                    'Все',
                                    style: TextStyle(fontSize: 12, color: theme.primaryColor),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () => setState(() => tempCategoryIds = []),
                                  child: Text(
                                    'Сбросить',
                                    style: TextStyle(fontSize: 12, color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: categories.map((category) {
                            return CustomFilterChip(
                              icon: Icons.label,
                              label: category.name,
                              isSelected: tempCategoryIds.contains(category.id),
                              onTap: () {
                                setState(() {
                                  if (tempCategoryIds.contains(category.id)) {
                                    tempCategoryIds.remove(category.id);
                                  } else {
                                    tempCategoryIds.add(category.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        if (tempCategoryIds.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Выбрано: ${tempCategoryIds.length} категорий',
                            style: TextStyle(fontSize: 12, color: theme.primaryColor),
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Тип курса',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      tempTypeIds = types
                                          .map((type) => type.id)
                                          .toList();
                                    });
                                  },
                                  child: Text(
                                    'Все',
                                    style: TextStyle(fontSize: 12, color: theme.primaryColor),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () => setState(() => tempTypeIds = []),
                                  child: Text(
                                    'Сбросить',
                                    style: TextStyle(fontSize: 12, color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: types.map((type) {
                            return CustomFilterChip(
                              icon: _getTypeIcon(type.name),
                              label: type.name,
                              isSelected: tempTypeIds.contains(type.id),
                              onTap: () {
                                setState(() {
                                  if (tempTypeIds.contains(type.id)) {
                                    tempTypeIds.remove(type.id);
                                  } else {
                                    tempTypeIds.add(type.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        if (tempTypeIds.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Выбрано: ${tempTypeIds.length} типов',
                            style: TextStyle(fontSize: 12, color: theme.primaryColor),
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        
                        Text(
                          'Дополнительно',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            CustomFilterChip(
                              icon: Icons.verified,
                              label: 'С сертификатом',
                              isSelected: hasCertificateFilter == true,
                              onTap: () {
                                setState(() {
                                  hasCertificateFilter = hasCertificateFilter == true ? null : true;
                                });
                              },
                            ),
                            CustomFilterChip(
                              icon: Icons.money_off,
                              label: 'Бесплатные',
                              isSelected: freeOnlyFilter == true,
                              onTap: () {
                                setState(() {
                                  freeOnlyFilter = freeOnlyFilter == true ? null : true;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.background,
                    border: Border(
                      top: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            side: BorderSide(color: theme.dividerColor),
                          ),
                          child: const Text('Отмена'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              await courseProvider.updateFilters(
                                categoryIds: tempCategoryIds,
                                typeIds: tempTypeIds,
                                hasCertificate: hasCertificateFilter,
                                freeOnly: freeOnlyFilter,
                                sortBy: selectedSortBy,
                                sortOrder: sortOrder,
                              );
                              if (mounted) Navigator.pop(context);
                            } catch (e) {
                              SnackBarHelper.showError(context, 'Ошибка применения фильтров');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Применить'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _countActiveFilters(CourseProvider courseProvider) {
    int count = 0;
    if (courseProvider.selectedCategoryIds.isNotEmpty) count++;
    if (courseProvider.selectedTypeIds.isNotEmpty) count++;
    if (courseProvider.currentHasCertificate != null) count++;
    if (courseProvider.currentFreeOnly != null) count++;
    if (courseProvider.currentSortBy != null) count++;
    if (courseProvider.currentSearchQuery?.isNotEmpty == true) count++;
    return count;
  }

  @override
  Widget buildContent(BuildContext context) {
    final theme = Theme.of(context);
    
    return Consumer2<CourseProvider, UserCourseProvider>(
      builder: (context, courseProvider, userCourseProvider, child) {
        final allCourses = courseProvider.allCourses;
        final searchQuery = courseProvider.currentSearchQuery ?? '';
        final selectedCategoryIds = courseProvider.selectedCategoryIds;
        final selectedTypeIds = courseProvider.selectedTypeIds;
        final hasCertificateFilter = courseProvider.currentHasCertificate;
        final freeOnlyFilter = courseProvider.currentFreeOnly;
        final selectedSortBy = courseProvider.currentSortBy;

        final hasActiveFilters = selectedCategoryIds.isNotEmpty || 
            selectedTypeIds.isNotEmpty || 
            hasCertificateFilter != null || 
            freeOnlyFilter != null ||
            selectedSortBy != null ||
            searchQuery.isNotEmpty;

        return Column(
          children: [
            AppBar(
              backgroundColor: theme.appBarTheme.backgroundColor,
              elevation: theme.appBarTheme.elevation ?? 2,
              title: const Text('Все курсы'),
              actions: [
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(Icons.filter_list, color: theme.colorScheme.onSurface),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => _buildFiltersDialog(context, courseProvider),
                        );
                      },
                      tooltip: 'Фильтры',
                    ),
                    if (hasActiveFilters)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            _countActiveFilters(courseProvider).toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: theme.colorScheme.onSurface),
                  onPressed: _loadCourses,
                  tooltip: 'Обновить',
                ),
              ],
            ),
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Card(
                            color: theme.cardTheme.color,
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                  if (searchQuery.isNotEmpty)
                                    GestureDetector(
                                      onTap: _clearSearch,
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(Icons.clear, size: 20, color: theme.hintColor),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (hasActiveFilters)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: InkWell(
                              onTap: _resetFilters,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.filter_alt_off,
                                  color: Colors.red,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  if (hasActiveFilters)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Text(
                              'Фильтры: ',
                              style: TextStyle(color: theme.hintColor, fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            if (searchQuery.isNotEmpty)
                              _buildFilterChip(
                                icon: Icons.search,
                                label: '"$searchQuery"',
                                color: theme.primaryColor,
                                onClear: _clearSearch,
                              ),
                            if (selectedCategoryIds.isNotEmpty)
                              _buildMultiFilterChip(
                                icon: Icons.category,
                                label: _getCategoryNames(courseProvider, selectedCategoryIds),
                                color: theme.primaryColor,
                                count: selectedCategoryIds.length,
                                onClear: _clearCategories,
                              ),
                            if (selectedTypeIds.isNotEmpty)
                              _buildMultiFilterChip(
                                icon: Icons.school,
                                label: _getTypeNames(courseProvider, selectedTypeIds),
                                color: theme.primaryColor,
                                count: selectedTypeIds.length,
                                onClear: _clearTypes,
                              ),
                            if (hasCertificateFilter == true)
                              _buildFilterChip(
                                icon: Icons.verified,
                                label: 'С сертификатом',
                                color: Colors.green,
                                onClear: _clearCertificate,
                              ),
                            if (freeOnlyFilter == true)
                              _buildFilterChip(
                                icon: Icons.money_off,
                                label: 'Бесплатные',
                                color: Colors.blue,
                                onClear: _clearFreeOnly,
                              ),
                            if (selectedSortBy != null)
                              _buildFilterChip(
                                icon: Icons.sort,
                                label: selectedSortBy == 'course_price' ? 'По цене' :
                                      selectedSortBy == 'course_hours' ? 'По часам' :
                                      selectedSortBy == 'rating' ? 'По рейтингу' : 'Сортировка',
                                color: const Color.fromARGB(255, 3, 3, 184),
                                onClear: _clearSorting,
                                showSortOrder: true,
                                sortOrder: courseProvider.currentSortOrder,
                              ),
                          ],
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Всего курсов: ${allCourses.length}',
                          style: TextStyle(color: theme.hintColor, fontSize: 14),
                        ),
                        if (searchQuery.isNotEmpty)
                          Text(
                            'По запросу: "$searchQuery"',
                            style: TextStyle(color: theme.primaryColor, fontSize: 14),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(color: theme.primaryColor),
                          )
                        : allCourses.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      searchQuery.isNotEmpty ? Icons.search_off : Icons.school,
                                      color: theme.hintColor,
                                      size: 64,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      searchQuery.isNotEmpty 
                                          ? 'По запросу "$searchQuery" курсы не найдены'
                                          : 'По вашим запросам курсы не были найдены',
                                      style: TextStyle(color: theme.hintColor, fontSize: 16),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (hasActiveFilters)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 16),
                                        child: TextButton(
                                          onPressed: _resetFilters,
                                          child: Text(
                                            'Сбросить фильтры',
                                            style: TextStyle(color: theme.primaryColor),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadCourses,
                                color: theme.primaryColor,
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: allCourses.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                                  itemBuilder: (context, index) {
                                    final course = allCourses[index];
                                    final isEnrolled = userCourseProvider.isUserEnrolled(course.id);
                                    
                                    return CourseCard(
                                      course: course.copyWith(isEnrolled: isEnrolled),
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
                                ),
                              ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onClear,
    bool showSortOrder = false,
    String sortOrder = 'asc',
  }) {
    return GestureDetector(
      onTap: onClear,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: EdgeInsets.only(left: 8, right: onClear != null ? 4 : 8, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w900),
            ),
            if (showSortOrder) ...[
              const SizedBox(width: 2),
              Icon(
                sortOrder == 'asc' ? Icons.arrow_upward : Icons.arrow_downward,
                size: 10,
                color: color,
              ),
            ],
            if (onClear != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.clear, size: 12, color: color),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiFilterChip({
    required IconData icon,
    required String label,
    required Color color,
    required int count,
    VoidCallback? onClear,
  }) {
    return GestureDetector(
      onTap: onClear,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: EdgeInsets.only(left: 8, right: onClear != null ? 4 : 8, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w900),
            ),
            if (count > 2)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w900),
                ),
              ),
            if (onClear != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.clear, size: 12, color: color),
              ),
          ],
        ),
      ),
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