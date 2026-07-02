import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:keepsyn_app/src/core/router/app_router.dart';
import 'package:keepsyn_app/src/features/auth/presentation/riverpod/auth_providers.dart';
import 'package:keepsyn_app/src/features/integrations/data/enums/integration_status.dart';
import 'package:keepsyn_app/src/features/integrations/presentation/riverpod/spotify_integration_provider.dart';
import 'package:keepsyn_app/src/features/integrations/presentation/riverpod/youtube_integration_provider.dart';
import 'package:keepsyn_app/src/features/sync/data/local/sync_local_store.dart';
import 'package:keepsyn_app/src/features/sync/presentation/riverpod/sync_controller_state.dart';
import 'package:keepsyn_app/src/features/sync/presentation/riverpod/sync_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotifyStatus = ref.watch(spotifyStatusProvider);
    final youtubeStatus = ref.watch(youtubeStatusProvider);
    final syncState = ref.watch(syncControllerProvider);
    final historyAsync = ref.watch(syncHistoryProvider);

    final spotifyOk =
        spotifyStatus.value == IntegrationStatus.connected;
    final youtubeOk =
        youtubeStatus.value == IntegrationStatus.connected;
    final bothConnected = spotifyOk && youtubeOk;
    final syncActive = syncState.isRunning || syncState.isPreparing;

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          if (syncActive) ...[
            _SyncBanner(syncState: syncState),
            const SizedBox(height: 20),
          ],

          Text(
            'INTEGRACIONES',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 8),
          _IntegrationTile(
            icon: Icons.graphic_eq_rounded,
            label: 'Spotify',
            statusAsync: spotifyStatus,
            onTap: () => context.push(AppRoutes.spotifyIntegration),
          ),
          const SizedBox(height: 8),
          _IntegrationTile(
            icon: Icons.smart_display_rounded,
            label: 'YouTube Music',
            statusAsync: youtubeStatus,
            onTap: () => context.push(AppRoutes.youtubeIntegration),
          ),

          const SizedBox(height: 24),

          if (bothConnected)
            FilledButton.icon(
              onPressed: syncActive
                  ? null
                  : () => context.push(AppRoutes.spotifyPlaylists),
              icon: const Icon(Icons.sync_rounded),
              label: Text(
                syncActive
                    ? 'Sincronización en curso...'
                    : 'Sincronizar playlist',
              ),
            )
          else
            _SetupHint(spotifyOk: spotifyOk, youtubeOk: youtubeOk),

          if (syncState.lastSyncAt != null) ...[
            const SizedBox(height: 28),
            Text(
              'ÚLTIMO SYNC',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: 1.2,
                  ),
            ),
            const SizedBox(height: 8),
            _LastSyncCard(syncState: syncState),
          ],

          historyAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (history) {
              if (history.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 28),
                  Text(
                    'HISTORIAL',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          letterSpacing: 1.2,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...history.take(5).map((e) => _HistoryTile(entry: e)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sync active banner
// ---------------------------------------------------------------------------

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.syncState});
  final SyncControllerState syncState;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(AppRoutes.sync),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  value: syncState.isPreparing ? null : syncState.progress,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  syncState.progressMessage ?? 'Sincronización en curso...',
                  style: TextStyle(color: cs.onPrimaryContainer),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Integration tile
// ---------------------------------------------------------------------------

class _IntegrationTile extends StatelessWidget {
  const _IntegrationTile({
    required this.icon,
    required this.label,
    required this.statusAsync,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final AsyncValue<IntegrationStatus> statusAsync;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(_subtitle(statusAsync)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusDot(statusAsync: statusAsync),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _subtitle(AsyncValue<IntegrationStatus> async) {
    if (async.isLoading) return 'Verificando...';
    final status = async.value;
    return switch (status) {
      IntegrationStatus.connected => 'Conectado',
      IntegrationStatus.linking => 'Vinculando...',
      IntegrationStatus.expired => 'Token expirado — toca para reconectar',
      IntegrationStatus.error => 'Error de conexión',
      _ => 'No conectado — toca para vincular',
    };
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.statusAsync});
  final AsyncValue<IntegrationStatus> statusAsync;

  @override
  Widget build(BuildContext context) {
    if (statusAsync.isLoading) {
      return const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final status = statusAsync.value;
    final color = switch (status) {
      IntegrationStatus.connected => Colors.green,
      IntegrationStatus.linking => Colors.orange,
      IntegrationStatus.expired => Colors.orange,
      _ => Colors.red.shade300,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ---------------------------------------------------------------------------
// Setup hint when not both connected
// ---------------------------------------------------------------------------

class _SetupHint extends StatelessWidget {
  const _SetupHint({required this.spotifyOk, required this.youtubeOk});
  final bool spotifyOk;
  final bool youtubeOk;

  @override
  Widget build(BuildContext context) {
    final missing = <String>[
      if (!spotifyOk) 'Spotify',
      if (!youtubeOk) 'YouTube Music',
    ];
    final text = missing.length == 1
        ? 'Conecta ${missing[0]} para poder sincronizar.'
        : 'Conecta Spotify y YouTube Music para poder sincronizar.';

    return Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Last sync card
// ---------------------------------------------------------------------------

class _LastSyncCard extends StatelessWidget {
  const _LastSyncCard({required this.syncState});
  final SyncControllerState syncState;

  @override
  Widget build(BuildContext context) {
    final status = syncState.lastSyncStatus;
    final at = syncState.lastSyncAt!;
    final result = syncState.result;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_statusIcon(status), size: 18, color: _statusColor(status)),
                const SizedBox(width: 8),
                Text(
                  _statusLabel(status),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _statusColor(status),
                      ),
                ),
                const Spacer(),
                Text(
                  _formatDate(at),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            if (result != null) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat(
                    value: result.created,
                    label: 'Agregadas',
                    color: Colors.green,
                  ),
                  _Stat(
                    value: result.skipped,
                    label: 'Omitidas',
                    color: Colors.orange,
                  ),
                  _Stat(
                    value: result.failed,
                    label: 'Fallidas',
                    color: Colors.red,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(SyncStatus? s) => switch (s) {
        SyncStatus.idle => Icons.check_circle_outline_rounded,
        SyncStatus.partialSuccess => Icons.warning_amber_rounded,
        SyncStatus.failed => Icons.error_outline_rounded,
        SyncStatus.cancelled => Icons.cancel_outlined,
        _ => Icons.check_circle_outline_rounded,
      };

  Color _statusColor(SyncStatus? s) => switch (s) {
        SyncStatus.idle => Colors.green,
        SyncStatus.partialSuccess => Colors.orange,
        SyncStatus.failed => Colors.red,
        SyncStatus.cancelled => Colors.grey,
        _ => Colors.green,
      };

  String _statusLabel(SyncStatus? s) => switch (s) {
        SyncStatus.idle => 'Completado',
        SyncStatus.partialSuccess => 'Completado con errores',
        SyncStatus.failed => 'Falló',
        SyncStatus.cancelled => 'Cancelado',
        _ => 'Completado',
      };

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Hace un momento';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// History tile
// ---------------------------------------------------------------------------

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});
  final SyncHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(entry.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(_statusIcon(entry.status), size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.playlistName ?? 'Sync reconectado',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${entry.created} agregadas · ${entry.skipped} omitidas · ${entry.failed} fallidas',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatDate(entry.completedAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(SyncStatus s) => switch (s) {
        SyncStatus.idle => Icons.check_circle_outline_rounded,
        SyncStatus.partialSuccess => Icons.warning_amber_rounded,
        SyncStatus.failed => Icons.error_outline_rounded,
        SyncStatus.cancelled => Icons.cancel_outlined,
        _ => Icons.check_circle_outline_rounded,
      };

  Color _statusColor(SyncStatus s) => switch (s) {
        SyncStatus.idle => Colors.green,
        SyncStatus.partialSuccess => Colors.orange,
        SyncStatus.failed => Colors.red,
        SyncStatus.cancelled => Colors.grey,
        _ => Colors.green,
      };

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return '${diff.inDays} días';
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }
}
