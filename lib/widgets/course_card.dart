import 'package:flutter/material.dart';
import '../models/course.dart';
import '../services/api_client.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;
  final ApiClient _apiClient = ApiClient();

  CourseCard({
    Key? key,
    required this.course,
    required this.onTap,
  }) : super(key: key);

  String? _getFullImageUrl() {
    if (course.photoPath == null || course.photoPath!.isEmpty) {
      return null;
    }
    return _apiClient.getImageUrl(course.photoPath);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = _getFullImageUrl();
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: double.infinity, 
                  height: 230, 
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: theme.colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imageUrl,
                            width: double.infinity,
                            height: 230,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildImagePlaceholder(theme);
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / 
                                        loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                          ),
                        )
                      : _buildImagePlaceholder(theme),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: course.isFree ? Colors.green.withOpacity(0.1) : theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: course.isFree ? Colors.green : theme.primaryColor,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      course.displayPrice,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: course.isFree ? Colors.green : theme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              Text(
                course.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 8),
              
              if (course.description != null && course.description!.isNotEmpty)
                Text(
                  course.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.hintColor,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              
              const SizedBox(height: 8),
              
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (course.category != null)
                    _buildChip(
                      label: course.category!.name,
                      color: theme.primaryColor,
                    ),
                  if (course.type != null)
                    _buildChip(
                      label: course.type!.name,
                      color: Colors.blue,
                    ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildInfoChip(
                    icon: Icons.access_time,
                    label: '${course.hours} ч',
                    theme: theme,
                  ),
                  if (course.hasCertificate)
                    _buildInfoChip(
                      icon: Icons.verified,
                      label: 'Сертификат',
                      theme: theme,
                    ),
                  if (course.rating > 0)
                    _buildInfoChip(
                      icon: Icons.star,
                      label: course.rating.toStringAsFixed(1),
                      color: Colors.amber,
                      theme: theme,
                    ),
                ],
              ),
              
              if (course.isEnrolled == true) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, color: Colors.green, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Вы записаны',
                        style: TextStyle(color: Colors.green, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school,
            size: 64,
            color: theme.hintColor.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Нет изображения',
            style: TextStyle(
              color: theme.hintColor.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    Color? color,
    required ThemeData theme,
  }) {
    final iconColor = color ?? theme.colorScheme.secondary;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: iconColor,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: iconColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}