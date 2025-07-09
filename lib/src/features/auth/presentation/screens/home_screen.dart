import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keepsyn_app/src/features/auth/presentation/riverpod/auth_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Obtenemos el usuario actual para mostrar su nombre.
    final user = ref.watch(authStateChangesProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('KeepSyn'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Llama al método de signOut.
              ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
      body: Center(child: Text('¡Bienvenido, ${user?.name ?? 'Usuario'}!')),
    );
  }
}
