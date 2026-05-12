import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoicehub/providers/auth_provider.dart';
import 'package:invoicehub/screens/auth/login_screen.dart';
import 'package:invoicehub/screens/auth/register_screen.dart';
import 'package:invoicehub/screens/splash/splash_screen.dart';
import 'package:invoicehub/screens/profile/complete_profile_screen.dart';
import 'package:invoicehub/screens/dashboard/dashboard_screen.dart';
import 'package:invoicehub/screens/admin/admin_dashboard_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final profileAsync = ref.watch(profileProvider);

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/complete-profile',
        builder: (context, state) => const CompleteProfileScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
    ],
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      
      if (authState.isLoading || profileAsync.isLoading) return null;

      final user = authState.value?.session?.user;
      if (user == null) {
        return loggingIn ? null : '/login';
      }

      final profile = profileAsync.value;
      if (profile == null) return null;

      if (!profile.isProfileCompleted && state.matchedLocation != '/complete-profile') {
        return '/complete-profile';
      }

      if (profile.isProfileCompleted && loggingIn) {
        return profile.role == 'super_admin' ? '/admin' : '/dashboard';
      }

      return null;
    },
  );
});
