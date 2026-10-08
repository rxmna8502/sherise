import 'package:go_router/go_router.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/otp_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/chat/presentation/screens/chat_screen.dart';
import '../features/jobs/data/models/job_model.dart';
import '../features/jobs/presentation/screens/job_detail_screen.dart';
import '../features/jobs/presentation/screens/post_job_screen.dart';
import '../features/navigation/presentation/screens/main_navigation_shell.dart';
import '../features/notifications/presentation/screens/notifications_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainNavigationShell(),
    ),
    GoRoute(
      path: '/take-work',
      builder: (context, state) => const MainNavigationShell(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/otp',
      builder: (context, state) {
        final extras = state.extra as Map<String, dynamic>?;
        return OtpScreen(
          email: extras?['email'] ?? '',
          phone: extras?['phone'] ?? '',
          name: extras?['name'] ?? '',
          isRegister: extras?['isRegister'] ?? false,
        );
      },
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) {
        final extras = state.extra as Map<String, dynamic>?;
        return RegisterScreen(
          email: extras?['email'] ?? '',
          phone: extras?['phone'] ?? '',
        );
      },
    ),
    GoRoute(
      path: '/job/:id',
      builder: (context, state) {
        final job = state.extra as JobModel?;
        if (job != null) {
          return JobDetailScreen(job: job);
        }
        return JobDetailScreen(
          job: JobModel(
            id: state.pathParameters['id'] ?? '',
            title: 'Work Details',
            description: '',
            category: 'Work',
            minAmount: 0,
            maxAmount: 0,
            postedAt: '',
          ),
        );
      },
    ),
    GoRoute(
      path: '/post-job',
      builder: (context, state) => const PostJobScreen(),
    ),
    GoRoute(
      path: '/chat/:jobId',
      builder: (context, state) {
        final jobId = state.pathParameters['jobId'] ?? '';
        final jobTitle = state.extra as String? ?? 'Chat';
        return ChatScreen(jobId: jobId, jobTitle: jobTitle);
      },
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
  ],
);
