import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/sign_in_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/home/presentation/pages/staff_home_page.dart';
import '../../features/home/presentation/pages/manager_home_page.dart';
import '../../features/roster/presentation/pages/roster_list_page.dart';
import '../../features/roster/presentation/pages/roster_upload_page.dart';
import '../../features/announcements/presentation/pages/announcements_page.dart';
import '../../features/chat/presentation/pages/chat_list_page.dart';
import '../../features/attendance/presentation/pages/attendance_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';

/// App router provider
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,

    redirect: (context, state) {
      final isAuthenticated = authState.value != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isSplash = state.matchedLocation == '/splash';

      // Loading state
      if (authState.isLoading) {
        return '/splash';
      }

      // Not authenticated and not on auth route
      if (!isAuthenticated && !isAuthRoute && !isSplash) {
        return '/auth/sign-in';
      }

      // Authenticated and on auth route
      if (isAuthenticated && (isAuthRoute || isSplash)) {
        return '/home';
      }

      // No redirect needed
      return null;
    },

    routes: [
      // Splash
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),

      // Auth routes
      GoRoute(
        path: '/auth/sign-in',
        name: 'sign-in',
        builder: (context, state) => const SignInPage(),
      ),

      // Home (role-based)
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) {
          // TODO: Determine role and show appropriate home page
          // For now, default to staff home
          return const StaffHomePage();
        },
      ),

      // Manager Home (with bottom nav)
      GoRoute(
        path: '/manager',
        name: 'manager',
        builder: (context, state) => const ManagerHomePage(),
      ),

      // Rosters
      GoRoute(
        path: '/rosters',
        name: 'rosters',
        builder: (context, state) => const RosterListPage(),
        routes: [
          GoRoute(
            path: 'upload',
            name: 'roster-upload',
            builder: (context, state) => const RosterUploadPage(),
          ),
        ],
      ),

      // Announcements
      GoRoute(
        path: '/announcements',
        name: 'announcements',
        builder: (context, state) => const AnnouncementsPage(),
      ),

      // Chat
      GoRoute(
        path: '/chat',
        name: 'chat',
        builder: (context, state) => const ChatListPage(),
      ),

      // Attendance
      GoRoute(
        path: '/attendance',
        name: 'attendance',
        builder: (context, state) => const AttendancePage(),
      ),

      // Profile
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
      ),

      // Settings
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],

    // Error handling
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.matchedLocation}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

/// Route names for easy navigation
class Routes {
  static const splash = '/splash';
  static const signIn = '/auth/sign-in';
  static const home = '/home';
  static const manager = '/manager';
  static const rosters = '/rosters';
  static const rosterUpload = '/rosters/upload';
  static const announcements = '/announcements';
  static const chat = '/chat';
  static const attendance = '/attendance';
  static const profile = '/profile';
  static const settings = '/settings';
}
