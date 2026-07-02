import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:keepsyn_app/src/features/auth/presentation/riverpod/auth_providers.dart';
import 'package:keepsyn_app/src/features/auth/presentation/screens/home_screen.dart';
import 'package:keepsyn_app/src/features/auth/presentation/screens/login_screen.dart';
import 'package:keepsyn_app/src/features/auth/presentation/screens/splash_screen.dart';
import 'package:keepsyn_app/src/features/integrations/presentation/screens/spotify_integration_screen.dart';
import 'package:keepsyn_app/src/features/integrations/presentation/screens/spotify_playlists_screen.dart';
import 'package:keepsyn_app/src/features/integrations/presentation/screens/youtube_integration_screen.dart';
import 'package:keepsyn_app/src/features/sync/presentation/screens/review_screen.dart';
import 'package:keepsyn_app/src/features/sync/presentation/screens/sync_screen.dart';

abstract class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const home = '/home';
  static const spotifyIntegration = '/integrations/spotify';
  static const spotifyPlaylists = '/integrations/spotify/playlists';
  static const youtubeIntegration = '/integrations/youtube';
  static const sync = '/sync';
  static const review = '/sync/review';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) =>
        const SplashScreen(message: 'Cargando sesión...'),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.spotifyIntegration,
        builder: (context, state) => const SpotifyIntegrationScreen(),
      ),
      GoRoute(
        path: AppRoutes.spotifyPlaylists,
        builder: (context, state) => const SpotifyPlaylistsScreen(),
      ),
      GoRoute(
        path: AppRoutes.youtubeIntegration,
        builder: (context, state) => const YouTubeIntegrationScreen(),
      ),
      GoRoute(
        path: AppRoutes.sync,
        builder: (context, state) => const SyncScreen(),
      ),
      GoRoute(
        path: AppRoutes.review,
        builder: (context, state) {
          final jobId = state.uri.queryParameters['jobId'] ?? '';
          return ReviewScreen(jobId: jobId);
        },
      ),
    ],
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isLogin = location == AppRoutes.login;
      final isSplash = location == AppRoutes.splash;

      if (authState.isBootstrapping) {
        return isSplash ? null : AppRoutes.splash;
      }

      if (!authState.isLoggedIn && !isLogin) {
        return AppRoutes.login;
      }

      if (authState.isLoggedIn && isLogin) {
        return AppRoutes.home;
      }

      if (isSplash) {
        return authState.isLoggedIn ? AppRoutes.home : AppRoutes.login;
      }

      return null;
    },
  );
});
