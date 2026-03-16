import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keepsyn_app/src/features/auth/presentation/riverpod/auth_providers.dart';
import 'package:keepsyn_app/src/features/auth/presentation/screens/home_screen.dart';
import 'package:keepsyn_app/src/features/auth/presentation/screens/login_screen.dart';
import 'package:keepsyn_app/src/features/auth/presentation/screens/splash_screen.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    if (authState.isBootstrapping || authState.isSubmitting) {
      return const SplashScreen(message: 'Verificando sesión...');
    }

    if (authState.hasError) {
      return const LoginScreen();
    }

    if (authState.isLoggedIn) {
      return const HomeScreen();
    }

    return const LoginScreen();
  }
}
