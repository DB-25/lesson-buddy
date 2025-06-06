import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../screens/create_course_screen.dart';
import '../screens/login_screen.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/theme_manager.dart';
import '../utils/logger.dart';
import '../widgets/course_card.dart';

class HomeScreen extends StatefulWidget {
  final Future<List<Course>>? preloadedCourses;

  const HomeScreen({super.key, this.preloadedCourses});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService.instance;
  late Future<List<Course>> _coursesFuture;
  bool _isLoading = false;
  final String _tag = 'HomeScreen';

  @override
  void initState() {
    super.initState();
    Logger.i(_tag, 'Screen initialized');

    if (widget.preloadedCourses != null) {
      Logger.i(_tag, 'Using preloaded courses from splash screen');
      _coursesFuture = widget.preloadedCourses!;
    } else {
      Logger.i(_tag, 'No preloaded courses, loading course list');
      _loadCourses();
    }
  }

  @override
  void dispose() {
    Logger.i(_tag, 'Screen disposed');
    super.dispose();
  }

  Future<void> _loadCourses() async {
    Logger.i(_tag, 'Loading course list');
    setState(() {
      _coursesFuture = _apiService.getCourseList();
    });
  }

  Future<void> _refreshCourses() async {
    Logger.i(_tag, 'Refreshing course list');
    setState(() {
      _isLoading = true;
    });

    try {
      await _loadCourses();
      Logger.i(_tag, 'Course list refreshed successfully');
    } catch (e) {
      Logger.e(
        _tag,
        'Error refreshing courses',
        error: e,
        stackTrace: StackTrace.current,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    Logger.i(_tag, 'User requested logout');

    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Logout'),
              ),
            ],
          ),
    );

    if (shouldLogout == true) {
      try {
        await _authService.logout();
        Logger.i(_tag, 'User logged out successfully');

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        Logger.e(_tag, 'Error during logout', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error during logout. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final isDarkMode = themeManager.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson Buddy'),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () async {
              final newMode = !isDarkMode ? 'dark' : 'light';
              Logger.i(_tag, 'User requested theme change to $newMode mode');
              await themeManager.toggleTheme();
            },
            tooltip:
                isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: 8),
                        Text('Logout'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshCourses,
        child: FutureBuilder<List<Course>>(
          future: _coursesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting ||
                _isLoading) {
              Logger.d(_tag, 'Loading courses...');
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              final error = snapshot.error;
              Logger.e(
                _tag,
                'Error loading courses',
                error: error,
                stackTrace: StackTrace.current,
              );
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading courses',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Logger.i(
                          _tag,
                          'User trying to reload courses after error',
                        );
                        _refreshCourses();
                      },
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              Logger.w(_tag, 'No courses available');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 60,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No courses available',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Logger.i(_tag, 'User refreshing empty course list');
                        _refreshCourses();
                      },
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              );
            }

            final courses = snapshot.data!;
            Logger.i(_tag, 'Loaded ${courses.length} courses');
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: courses.length,
              itemBuilder: (context, index) {
                final course = courses[index];
                Logger.v(_tag, 'Rendering course: ${course.title}');
                return CourseCard(course: course);
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Logger.i(_tag, 'User navigating to create course screen');
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateCourseScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
