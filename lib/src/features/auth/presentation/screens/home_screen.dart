import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keepsyn_app/src/core/router/app_router.dart';
import 'package:keepsyn_app/src/features/auth/presentation/riverpod/auth_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('KeepSyn'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            user?.email != null
                ? 'Bienvenido ${user!.email}'
                : 'Bienvenido',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Configura tus integraciones y luego iniciamos la sincronizacion.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.graphic_eq_rounded),
              title: const Text('Conectar Spotify'),
              subtitle: const Text('Vincula tu cuenta para leer playlists'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(AppRoutes.spotifyIntegration),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.smart_display_rounded),
              title: const Text('Conectar YouTube Music'),
              subtitle: const Text('Configura el destino de sincronizacion'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(AppRoutes.youtubeIntegration),
            ),
          ),
        ],
      ),
    );
  }
}
