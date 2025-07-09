import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keepsyn_app/src/features/auth/presentation/riverpod/auth_providers.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar Sesión')),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.login), // Puedes poner un logo de Google aquí
          label: const Text('Iniciar sesión con Google'),
          onPressed: () {
            // Llama al método de signIn del repositorio.
            // No es necesario manejar el estado de carga aquí,
            // el AuthWrapper lo hará por nosotros.
            ref.read(authRepositoryProvider).signInWithGoogle();
          },
        ),
      ),
    );
  }
}
