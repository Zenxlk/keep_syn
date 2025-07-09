import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keepsyn_app/src/features/auth/presentation/riverpod/auth_providers.dart';
import 'package:keepsyn_app/src/features/auth/presentation/screens/home_screen.dart';
import 'package:keepsyn_app/src/features/auth/presentation/screens/login_screen.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escucha el stream del estado de autenticación.
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      // Mientras carga, muestra un indicador.
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      // Si hay un error en el stream, muestra un error.
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      // Cuando tenemos datos:
      data: (user) {
        // Si el usuario no es nulo, está logueado.
        if (user != null) {
          return const HomeScreen();
        }
        // Si es nulo, no está logueado.
        return const LoginScreen();
      },
    );
  }
}
