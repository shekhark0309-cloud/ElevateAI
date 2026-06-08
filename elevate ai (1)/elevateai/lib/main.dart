import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'firebase_options.dart';
import 'config/app_config.dart';
import 'config/notification_service.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/slg_visualization.dart';
import 'screens/team_finder_screen.dart';
import 'screens/opportunity_feed_screen.dart';
import 'screens/scheme_simulator_screen.dart';
import 'screens/career_predictor_screen.dart';
import 'screens/scam_shield_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/portfolio_screen.dart';
import 'screens/dna_quiz_screen.dart';
import 'screens/skill_reality_screen.dart';
import 'screens/open_roles_screen.dart';
import 'screens/post_hackathon_screen.dart';
import 'screens/campus_connect_screen.dart';
import 'screens/achievements_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/sustainability_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? initError;
  try {
    AppConfig.validate();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
    await PushNotificationService.initialize();
  } catch (e) {
    debugPrint('Initialization error: $e');
    initError = e.toString();
  }

  runApp(ElevateAIApp(error: initError));
}

final _router = GoRouter(
  initialLocation: '/welcome',
  redirect: (context, state) {
    try {
      final supabase = Supabase.instance.client;
      final isLoggedIn = supabase.auth.currentSession != null;

      final publicRoutes = [
        '/welcome',
        '/onboarding',
        '/dna_quiz',
        '/main',
        '/home',
        '/profile',
        '/team_finder',
        '/campus_connect',
        '/slg',
        '/opportunities',
        '/scam_shield',
        '/scheme_simulator',
        '/notifications',
        '/sustainability'
      ];
      final isPublicRoute = publicRoutes.contains(state.matchedLocation);

      if (!isLoggedIn && !isPublicRoute) {
        return '/welcome';
      }
    } catch (e) {
      // Supabase not initialized or other error
      return null;
    }

    return null;
  },
  routes: [
    GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
    GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
    GoRoute(path: '/dna_quiz', builder: (context, state) => const DNAQuizScreen()),
    GoRoute(path: '/main', builder: (context, state) => const MainNavigationScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
    GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
    GoRoute(path: '/slg', builder: (context, state) => const SLGVisualizationScreen()),
    GoRoute(path: '/team_finder', builder: (context, state) => const TeamFinderScreen()),
    GoRoute(path: '/opportunities', builder: (context, state) => const OpportunityFeedScreen()),
    GoRoute(path: '/scheme_simulator', builder: (context, state) => const SchemeSimulatorScreen()),
    GoRoute(path: '/career_predictor', builder: (context, state) => const CareerPredictorScreen()),
    GoRoute(path: '/scam_shield', builder: (context, state) => const ScamShieldScreen()),
    GoRoute(path: '/leaderboard', builder: (context, state) => const LeaderboardScreen()),
    GoRoute(path: '/portfolio', builder: (context, state) => const PortfolioScreen()),
    GoRoute(path: '/skill_reality', builder: (context, state) => const SkillRealityScreen()),
    GoRoute(path: '/open_roles', builder: (context, state) => const OpenRolesScreen()),
    GoRoute(path: '/campus_connect', builder: (context, state) => const CampusConnectScreen()),
    GoRoute(path: '/achievements', builder: (context, state) => const AchievementsScreen()),
    GoRoute(path: '/conversations', builder: (context, state) => const ChatListScreen()),
    GoRoute(path: '/sustainability', builder: (context, state) => const SustainabilityDashboardScreen()),
    GoRoute(
      path: '/chat/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final name = state.uri.queryParameters['name'];
        return ChatScreen(conversationId: id, otherUserName: name);
      },
    ),
    GoRoute(
      path: '/post_hackathon/:teamId',
      builder: (context, state) {
        final teamId = state.pathParameters['teamId'] ?? '';
        return PostHackathonScreen(teamId: teamId);
      },
    ),
  ],
);

class ElevateAIApp extends StatelessWidget {
  final String? error;
  const ElevateAIApp({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 24),
                  const Text(
                    'Configuration Error',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Please ensure your Supabase URL and Key are correctly set in AppConfig.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MaterialApp.router(
      title: 'ElevateAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6200EE),
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        fontFamily: 'Roboto',
      ),
      routerConfig: _router,
    );
  }
}
