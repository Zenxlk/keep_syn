import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            LinearProgressIndicator(value: syncState.progress),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
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
                      isSyncing: !syncState.canStartNewSync,
                      onSync: () => _startSync(context, ref, playlist),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    error.toString(),
                    textAlign: TextAlign.center,
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
    try {
      final tracks = await ref.read(
        spotifyPlaylistTracksProvider(playlist.id).future,
      );

      final domainPlaylist = playlist.toDomain(tracks);
      final job = SyncJob(
        jobId:
            'spotify_${playlist.id}_${DateTime.now().millisecondsSinceEpoch}',
        sourcePlatform: 'spotify',
        targetPlatform: 'youtube',
        sourcePlaylistId: playlist.id,
        requestedAt: DateTime.now(),
      );

      await ref.read(syncControllerProvider.notifier).startSync(
            job: job,
            sourcePlaylist: domainPlaylist,
          );

      if (context.mounted) {
        context.push(AppRoutes.sync);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo iniciar sync: $e')),
        );
      }
    }
  }
}

class _PlaylistCard extends StatelessWidget {
  final SpotifyPlaylistModel playlist;
  final bool isSyncing;
  final VoidCallback onSync;

  const _PlaylistCard({
    required this.playlist,
    required this.isSyncing,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
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
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: isSyncing ? null : onSync,
              child: const Text('Sincronizar'),
            ),
          ],
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
