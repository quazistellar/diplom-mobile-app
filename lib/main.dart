import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:unireax_mobile_diplom/services/api_client.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'screens/auth_screen.dart';
import 'screens/main_screen.dart';
import 'screens/courses_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/results_screen.dart';
import 'screens/certificate_detail_screen.dart';
import 'screens/password_reset_screen.dart';
import 'screens/register_screen.dart';
import 'screens/assignment_detail_screen.dart';
import 'screens/test_screen.dart';
import 'screens/test_results_screen.dart';
import 'screens/profile_screen.dart'; 
import 'providers/auth_provider.dart';
import 'providers/certificate_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/progress_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/course_provider.dart';
import 'providers/user_course_provider.dart';
import 'providers/statistics_provider.dart';

/// данная функция является точкой входа в приложение
void main() async {  
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    AndroidWebViewController.enableDebugging(true);
  }
  
  // проверка доступного URL для устройства
  await ApiClient.checkDeviceUrl();  
  
  runApp(const MyApp());
}

/// данный класс представляет корневое приложение
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<ThemeManager>(create: (_) => ThemeManager()),
        ChangeNotifierProvider<ProgressProvider>(create: (_) => ProgressProvider()),
        ChangeNotifierProvider<CertificateProvider>(create: (_) => CertificateProvider()),
        ChangeNotifierProvider<NavigationProvider>(create: (_) => NavigationProvider()),
        ChangeNotifierProvider<CourseProvider>(create: (_) => CourseProvider()),
        ChangeNotifierProvider<UserCourseProvider>(create: (_) => UserCourseProvider()),
        ChangeNotifierProvider<StatisticsProvider>(create: (_) => StatisticsProvider()),
      ],
      child: Consumer2<ThemeManager, AuthProvider>(
        builder: (context, themeManager, authProvider, child) {
          return MaterialApp(
            title: 'Unireax',
            theme: themeManager.currentTheme,
            darkTheme: themeManager.currentTheme,
            themeMode: themeManager.themeMode,
            debugShowCheckedModeBanner: false,
            home: FutureBuilder<bool>(
              future: authProvider.checkAuth(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !authProvider.isLoginInProgress) {
                  return Scaffold(
                    backgroundColor: themeManager.currentTheme.colorScheme.background,
                    body: Center(
                      child: CircularProgressIndicator(
                        color: themeManager.currentTheme.colorScheme.primary,
                      ),
                    ),
                  );
                }
                
                if (authProvider.isAuthenticated) {
                  return const MainScreen();
                }
                
                return const AuthScreen();
              },
            ),
            routes: {
              '/auth': (context) => const AuthScreen(),
              '/main': (context) => const MainScreen(),
              '/courses': (context) => const CoursesScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/progress': (context) => const ProgressScreen(),
              '/results': (context) => const ResultsScreen(),
              '/register': (context) => const RegisterScreen(),
              '/profile': (context) => const ProfileScreen(), 
              '/password-reset': (context) {
                final email = ModalRoute.of(context)?.settings.arguments as String;
                return PasswordResetScreen(email: email);
              },
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/certificate/detail') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) => CertificateDetailScreen(
                    certificate: args['certificate'],
                    course: args['course'],
                  ),
                );
              }
              
              if (settings.name == '/assignment-detail') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) => AssignmentDetailScreen(
                    courseId: args['courseId'],
                    assignmentId: args['assignmentId'],
                  ),
                );
              }
              
              if (settings.name == '/test') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) => TestScreen(
                    courseId: args['courseId'],
                    testId: args['testId'],
                  ),
                );
              }
              
              if (settings.name == '/test-result') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) => TestResultScreen(
                    testResultId: args['testResultId'],
                    courseId: args['courseId'],
                    testId: args['testId'],
                  ),
                );
              }
              
              return null;
            },
          );
        },
      ),
    );
  }
}