import 'package:flutter/material.dart';
import '../models/lesson.dart';
import '../screens/lesson_view_screen.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

class LessonTile extends StatefulWidget {
  final Lesson? lesson;
  final VoidCallback? onTap;
  final String? courseId;
  final VoidCallback? onRefreshNeeded;

  const LessonTile({
    super.key,
    this.lesson,
    this.onTap,
    this.courseId,
    this.onRefreshNeeded,
  });

  @override
  State<LessonTile> createState() => _LessonTileState();
}

class _LessonTileState extends State<LessonTile> {
  final ApiService _apiService = ApiService();
  bool _isGenerating = false;
  final String _tag = 'LessonTile';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lesson = widget.lesson;
    final bool isGenerated = lesson?.generated ?? false;
    final bool isCompleted = lesson?.completed ?? false;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: theme.colorScheme.surface,
      child: ListTile(
        title: Text(
          lesson?.title ?? 'Lesson Title',
          style: theme.textTheme.bodyLarge?.copyWith(
            color:
                !isGenerated
                    ? theme.colorScheme.onSurface.withAlpha(153)
                    : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lesson?.content != null && lesson!.content.isNotEmpty)
              Text(
                lesson.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      !isGenerated
                          ? theme.colorScheme.onSurface.withAlpha(128)
                          : null,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (isCompleted)
                  _buildStatusChip(
                    icon: Icons.check_circle,
                    label: 'Completed',
                    backgroundColor: Colors.green.withAlpha(51),
                    textColor: Colors.green,
                    iconColor: Colors.green,
                  ),
                if (!isGenerated)
                  _buildStatusChip(
                    icon: _isGenerating ? Icons.sync : Icons.pending,
                    label: _isGenerating ? 'Generating...' : 'Not Generated',
                    backgroundColor: Colors.orange.withAlpha(51),
                    textColor: Colors.orange,
                    iconColor: Colors.orange,
                  ),
                if (isGenerated && !isCompleted)
                  _buildStatusChip(
                    icon: Icons.play_arrow,
                    label: 'Start Lesson',
                    backgroundColor: colorScheme.primary.withAlpha(51),
                    textColor: colorScheme.primary,
                    iconColor: colorScheme.primary,
                  ),
              ],
            ),
          ],
        ),
        leading: CircleAvatar(
          backgroundColor:
              isGenerated
                  ? (isCompleted
                      ? Colors.green.withAlpha(51)
                      : theme.colorScheme.primary.withAlpha(51))
                  : Colors.orange.withAlpha(51),
          child: Icon(
            isGenerated
                ? (isCompleted ? Icons.check : Icons.book)
                : Icons.pending,
            color:
                isGenerated
                    ? (isCompleted ? Colors.green : theme.colorScheme.primary)
                    : Colors.orange,
            size: 20,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isGenerated && !_isGenerating)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _generateChapterContent,
                tooltip: 'Generate content',
              ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color:
                  isGenerated
                      ? theme.colorScheme.onSurface.withAlpha(153)
                      : theme.colorScheme.onSurface.withAlpha(77),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        enabled: isGenerated,
        onTap:
            isGenerated
                ? (widget.onTap ??
                    () => _navigateToLessonView(context, widget.lesson))
                : _promptGenerateContent,
      ),
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color textColor,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateChapterContent() async {
    if (widget.lesson == null || widget.courseId == null) return;

    final chapterId = _extractChapterId(widget.lesson!.sectionId);
    if (chapterId.isEmpty) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      await _apiService.generateChapter(
        courseId: widget.courseId!,
        chapterId: chapterId,
      );

      // Show toast or snackbar
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Content generation started. This may take a few minutes.',
          ),
          duration: Duration(seconds: 5),
        ),
      );

      // Notify parent to refresh after some time
      if (widget.onRefreshNeeded != null) {
        Future.delayed(const Duration(seconds: 30), () {
          if (mounted) widget.onRefreshNeeded!();
        });
      }
    } catch (e) {
      Logger.e(_tag, 'Error generating chapter content', error: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate content: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  void _promptGenerateContent() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Content Not Generated'),
            content: const Text(
              'This lesson content hasn\'t been generated yet. Would you like to generate it now?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _generateChapterContent();
                },
                child: const Text('Generate'),
              ),
            ],
          ),
    );
  }

  String _extractChapterId(String sectionId) {
    // Try to extract chapter ID from sectionId (e.g., "chapter_2" -> "2")
    if (sectionId.contains('chapter-')) {
      return sectionId;
    } else if (sectionId.contains('_')) {
      return sectionId.split('_').last;
    }
    return sectionId;
  }

  void _navigateToLessonView(BuildContext context, Lesson? lesson) {
    if (lesson == null || widget.courseId == null) {
      _showLessonDetails(context, lesson);
      return;
    }

    final chapterId = _extractChapterId(lesson.sectionId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => LessonViewScreen(
              courseId: widget.courseId!,
              chapterId: chapterId,
              lessonId: lesson.id,
              lessonTitle: lesson.title,
              lesson: lesson,
            ),
      ),
    );
  }

  void _showLessonDetails(BuildContext context, Lesson? lesson) {
    if (lesson == null) return;

    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          lesson.title,
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        Text(lesson.content, style: theme.textTheme.bodyMedium),
                        if (lesson.resources.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text('Resources', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          ...lesson.resources.map(
                            (resource) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.link,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      resource,
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }
}
