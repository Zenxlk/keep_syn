import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keepsyn_app/src/features/sync/presentation/riverpod/sync_controller_state.dart';
import 'package:keepsyn_app/src/features/sync/presentation/riverpod/sync_providers.dart';

class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncControllerProvider);
    final notifier = ref.read(syncControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estado de sincronizacion'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estado: ${_statusLabel(state.status)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (state.isRunning || state.isPreparing)
                    const LinearProgressIndicator()
                  else
                    LinearProgressIndicator(value: state.progress),
                  const SizedBox(height: 8),
                  Text('${(state.progress * 100).toStringAsFixed(0)}%'),
                  const SizedBox(height: 8),
                  Text(
                    state.progressMessage ??
                        (state.isRunning || state.isPreparing
                            ? 'Esperando actualizacion del backend...'
                            : 'Sincronizacion inactiva.'),
                  ),
                  if (state.activeJob != null) ...[
                    const SizedBox(height: 8),
                    Text('Job: ${state.activeJob!.jobId}'),
                    Text(
                      'Origen: ${state.activeJob!.sourcePlatform} · Destino: ${state.activeJob!.targetPlatform}',
                    ),
                    Text('Playlist origen: ${state.activeJob!.sourcePlaylistId}'),
                  ],
                ],
              ),
            ),
          ),
          if (state.result != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resultado',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Procesados: ${state.result!.processed}'),
                    Text('Creados: ${state.result!.created}'),
                    Text('Omitidos: ${state.result!.skipped}'),
                    Text('Fallidos: ${state.result!.failed}'),
                  ],
                ),
              ),
            ),
            if (state.result!.errors.isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                child: ExpansionTile(
                  leading: Icon(
                    Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text('Tracks fallidos (${state.result!.errors.length})'),
                  children: state.result!.errors.map((error) {
                    return ListTile(
                      dense: true,
                      title: Text(
                        error.message,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      subtitle: Text(
                        '${error.code} · ${error.trackId}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
          if (state.hasError) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  state.failure?.message ?? 'Error desconocido de sincronizacion.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (state.isRunning || state.isPreparing)
            FilledButton.icon(
              onPressed: () => notifier.cancelActiveSync(),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Cancelar sincronizacion'),
            ),
          if (state.isFinished || state.isIdle)
            OutlinedButton.icon(
              onPressed: () => notifier.reset(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Limpiar estado'),
            ),
        ],
      ),
    );
  }

  String _statusLabel(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return 'Idle';
      case SyncStatus.preparing:
        return 'Preparando';
      case SyncStatus.running:
        return 'En progreso';
      case SyncStatus.partialSuccess:
        return 'Parcial';
      case SyncStatus.failed:
        return 'Fallido';
      case SyncStatus.cancelled:
        return 'Cancelado';
    }
  }
}

