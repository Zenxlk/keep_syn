import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:keepsyn_app/src/core/router/app_router.dart';
import 'package:keepsyn_app/src/features/integrations/data/models/spotify_playlist_model.dart';
import 'package:keepsyn_app/src/features/integrations/presentation/riverpod/spotify_integration_provider.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_job.dart';
import 'package:keepsyn_app/src/features/sync/presentation/riverpod/sync_providers.dart';

class SpotifyPlaylistsScreen extends ConsumerStatefulWidget {
  const SpotifyPlaylistsScreen({super.key});

  @override
  ConsumerState<SpotifyPlaylistsScreen> createState() =>
      _SpotifyPlaylistsScreenState();
}

class _SpotifyPlaylistsScreenState extends ConsumerState<SpotifyPlaylistsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String? _loadingPlaylistId;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final playlistsAsync = ref.watch(spotifyPlaylistsProvider);
    final syncState = ref.watch(syncControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.spotifyIntegration);
            }
          },
        ),
        title: const Text('Playlists de Spotify'),
        actions: [
          IconButton(
            tooltip: 'Recargar playlists',
            onPressed: () => ref.invalidate(spotifyPlaylistsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (syncState.isRunning || syncState.isPreparing)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(
                value: syncState.isPreparing ? null : syncState.progress,
              ),
            ),
          if (syncState.isRunning || syncState.isPreparing)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.sync_rounded),
                  title: Text(
                    syncState.progressMessage ?? 'Sincronizando playlist...',
                  ),
                  subtitle: Text(
                    '${(syncState.progress * 100).toStringAsFixed(0)}% · ${syncState.activeJob?.sourcePlaylistId ?? ''}',
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar playlist...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: playlistsAsync.when(
              data: (playlists) {
                final filtered = _filterPlaylists(playlists, _query);
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      playlists.isEmpty
                          ? 'No se encontraron playlists en Spotify.'
                          : 'No hay resultados para "$_query".',
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final playlist = filtered[index];
                    return _PlaylistCard(
                      playlist: playlist,
                      isSyncing: !syncState.canStartNewSync ||
                          _loadingPlaylistId != null ||
                          playlist.isSpotifyGenerated,
                      isLoading: _loadingPlaylistId == playlist.id,
                      onSync: playlist.isSpotifyGenerated
                          ? null
                          : () => _startSync(context, ref, playlist),
                    );
                  },
                );
              },
              loading: () => const _PlaylistsShimmer(),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reintentar'),
                        onPressed: () => ref.invalidate(spotifyPlaylistsProvider),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<SpotifyPlaylistModel> _filterPlaylists(
    List<SpotifyPlaylistModel> playlists,
    String query,
  ) {
    if (query.isEmpty) return playlists;

    final q = query.toLowerCase();
    return playlists.where((playlist) {
      final nameMatch = playlist.name.toLowerCase().contains(q);
      final ownerMatch = (playlist.ownerName ?? '').toLowerCase().contains(q);
      return nameMatch || ownerMatch;
    }).toList(growable: false);
  }

  Future<void> _startSync(
    BuildContext context,
    WidgetRef ref,
    SpotifyPlaylistModel playlist,
  ) async {
    if (_loadingPlaylistId != null) return;
    setState(() => _loadingPlaylistId = playlist.id);

    try {
      final tracks = await ref
          .read(spotifyDataSourceProvider)
          .getPlaylistTracks(playlist.id);

      final domainPlaylist = playlist.toDomain(tracks);
      final job = SyncJob(
        jobId:
            'spotify_${playlist.id}_${DateTime.now().millisecondsSinceEpoch}',
        sourcePlatform: 'spotify',
        targetPlatform: 'youtube',
        sourcePlaylistId: playlist.id,
        requestedAt: DateTime.now(),
      );

      if (!context.mounted) return;
      context.push(AppRoutes.sync);

      await ref.read(syncControllerProvider.notifier).startSync(
            job: job,
            sourcePlaylist: domainPlaylist,
          );
    } catch (e) {
      if (context.mounted) {
        final msg = _friendlyError(e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPlaylistId = null);
    }
  }

  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('generada por spotify') ||
        lower.contains('daily mix') ||
        lower.contains('on repeat') ||
        lower.contains('privada de otro')) {
      return 'Esta playlist no puede sincronizarse. '
          'Spotify no permite acceder a sus tracks por API '
          '(puede ser una playlist generada por Spotify o privada de otro usuario).';
    }
    if (raw.contains('403') ||
        lower.contains('permisos') ||
        lower.contains('permiso')) {
      return 'Spotify no permite leer esta playlist. '
          'Ve a Integraciones → Spotify, desvincula y vuelve a conectar.';
    }
    if (raw.contains('401') || lower.contains('expiró')) {
      return 'Sesión de Spotify expirada. '
          'Ve a Integraciones → Spotify, desvincula y vuelve a conectar.';
    }
    return 'No se pudieron cargar los tracks: $raw';
  }
}

class _PlaylistCard extends StatelessWidget {
  final SpotifyPlaylistModel playlist;
  final bool isSyncing;
  final bool isLoading;
  final VoidCallback? onSync;

  const _PlaylistCard({
    required this.playlist,
    required this.isSyncing,
    required this.isLoading,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final isRestricted = playlist.isSpotifyGenerated;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _Artwork(imageUrl: playlist.imageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${playlist.tracksTotal} tracks'
                    '${playlist.ownerName != null ? ' · ${playlist.ownerName}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (isRestricted) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Generada por Spotify · no compatible',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isRestricted)
              Tooltip(
                message: 'Spotify no permite sincronizar\nplaylists generadas automáticamente.',
                child: Icon(
                  Icons.block_rounded,
                  color: Theme.of(context).colorScheme.outline,
                  size: 22,
                ),
              )
            else
              FilledButton(
                onPressed: isSyncing ? null : onSync,
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Sincronizar'),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistsShimmer extends StatelessWidget {
  const _PlaylistsShimmer();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Theme.of(context).colorScheme.surface;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(width: 64, height: 64, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 11,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  final String? imageUrl;

  const _Artwork({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 64,
        height: 64,
        child: imageUrl != null
            ? Image.network(imageUrl!, fit: BoxFit.cover)
            : Container(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.queue_music_rounded,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
      ),
    );
  }
}
