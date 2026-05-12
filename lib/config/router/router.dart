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
      final loc = state.matchedLocation;
      final loggingIn = loc == '/login' || loc == '/register';
      final atSplash = loc == '/';
      final atCompleteProfile = loc == '/complete-profile';

      // 1️⃣ Wait for Supabase auth to resolve
      if (authState.isLoading) return null;

      final user = authState.value?.session?.user;

      // 2️⃣ Not logged in — go to login
      if (user == null) {
        return loggingIn ? null : '/login';
      }

      // 3️⃣ Profile is still loading — hold on splash to avoid premature redirects
      if (profileAsync.isLoading) {
        return atSplash ? null : '/';
      }

      final profile = profileAsync.value;

      // Helper: is this user an admin?
      String resolvedRole = 'shop_owner';
      if (profile != null) {
        resolvedRole = profile.role.toLowerCase();
      } else {
        // Fallback: check userMetadata in case profile row doesn't exist in DB
        final meta = user.userMetadata ?? {};
        resolvedRole = (meta['role'] ?? 'shop_owner').toString().toLowerCase();
      }
      final isAdmin = resolvedRole == 'admin' ||
          resolvedRole == 'super_admin' ||
          resolvedRole == 'superadmin';

      // 4️⃣ Admin — always go to /admin, never show complete-profile
      if (isAdmin) {
        if (loggingIn || atSplash || atCompleteProfile) return '/admin';
        return null;
      }

      // 5️⃣ Shop owner — check profile completion
      if (profile == null || !profile.isProfileCompleted) {
        return atCompleteProfile ? null : '/complete-profile';
      }

      if (loggingIn || atSplash) return '/dashboard';

      return null;
    },
  );
});
