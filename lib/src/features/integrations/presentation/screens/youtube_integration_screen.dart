import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keepsyn_app/src/core/router/app_router.dart';
import 'package:keepsyn_app/src/features/integrations/data/enums/integration_status.dart';
import 'package:keepsyn_app/src/features/integrations/presentation/riverpod/youtube_integration_provider.dart';

class YouTubeIntegrationScreen extends ConsumerWidget {
  const YouTubeIntegrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(youtubeStatusProvider);
    final notifier = ref.read(youtubeStatusProvider.notifier);
    final status = statusAsync.valueOrNull;
    final isConnected = status == IntegrationStatus.connected;
    final isLinking = status == IntegrationStatus.linking;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        title: const Text('Integracion YouTube Music'),
        actions: [
          IconButton(
            tooltip: 'Actualizar estado',
            onPressed: () => notifier.checkStatus(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          statusAsync.when(
            data: (value) => _StatusCard(status: value),
            loading: () => const _LoadingCard(),
            error: (error, _) => _ErrorCard(message: error.toString()),
          ),
          const SizedBox(height: 16),
          if (!isConnected)
            FilledButton.icon(
              onPressed:
                  statusAsync.isLoading || isLinking
                      ? null
                      : () => notifier.linkWithYouTube(),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Vincular YouTube'),
            ),
          if (isConnected)
            OutlinedButton.icon(
              onPressed: () => notifier.unlinkAccount(),
              icon: const Icon(Icons.link_off_rounded),
              label: const Text('Desvincular YouTube'),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => notifier.checkStatus(),
            icon: const Icon(Icons.sync_rounded),
            label: const Text('Consultar estado'),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IntegrationStatus status;

  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _mapStatus(context, status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.smart_display_rounded, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Estado actual: $label',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, Color) _mapStatus(BuildContext context, IntegrationStatus value) {
    final cs = Theme.of(context).colorScheme;
    switch (value) {
      case IntegrationStatus.connected:
        return ('Conectado', cs.primary);
      case IntegrationStatus.linking:
        return ('Vinculando', cs.tertiary);
      case IntegrationStatus.expired:
        return ('Expirado', cs.error);
      case IntegrationStatus.notConnected:
        return ('No conectado', cs.outline);
      case IntegrationStatus.error:
        return ('Error', cs.error);
    }
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Consultando estado de YouTube...')),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: cs.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: cs.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
