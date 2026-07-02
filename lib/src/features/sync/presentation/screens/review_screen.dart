import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keepsyn_app/src/features/sync/data/repositories/sync_repository_impl.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/review_item.dart';
import 'package:keepsyn_app/src/features/sync/presentation/riverpod/sync_providers.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.jobId});
  final String jobId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  late Future<List<ReviewPendingItem>> _itemsFuture;
  final Map<String, ReviewDecision> _decisions = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _loadItems();
  }

  Future<List<ReviewPendingItem>> _loadItems() async {
    final result = await ref
        .read(syncRepositoryProvider)
        .getReviewItems(jobId: widget.jobId);
    return result.fold(
      (failure) => throw failure,
      (items) => items,
    );
  }

  Future<void> _submit(List<ReviewPendingItem> items) async {
    final pending = items
        .where((item) => !_decisions.containsKey(item.sourceTrack.id))
        .toList();

    if (pending.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Tracks sin decisión'),
          content: Text(
            '${pending.length} track(s) no tienen decisión asignada y se omitirán. ¿Continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final decisions = [
      ..._decisions.values,
      ...pending.map(
        (item) => ReviewDecision.skip(sourceTrackId: item.sourceTrack.id),
      ),
    ];

    setState(() => _submitting = true);
    final result = await ref.read(syncRepositoryProvider).submitReview(
          jobId: widget.jobId,
          decisions: decisions,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message ?? 'Error enviando revisión.')),
      ),
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Revisión enviada correctamente.')),
        );
        Navigator.of(context).pop(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracks en revisión'),
      ),
      body: FutureBuilder<List<ReviewPendingItem>>(
        future: _itemsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48),
                  const SizedBox(height: 12),
                  Text('No se pudieron cargar los tracks.'),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () =>
                        setState(() => _itemsFuture = _loadItems()),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text('No hay tracks pendientes de revisión.'),
            );
          }

          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  'Estos ${items.length} track(s) tienen una coincidencia ambigua. '
                  'Aprueba el match sugerido o márcalos para omitir.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final decision = _decisions[item.sourceTrack.id];
                    return _ReviewItemCard(
                      item: item,
                      decision: decision,
                      onApprove: (videoId) => setState(() {
                        _decisions[item.sourceTrack.id] =
                            ReviewDecision.approve(
                          sourceTrackId: item.sourceTrack.id,
                          videoId: videoId,
                        );
                      }),
                      onSkip: () => setState(() {
                        _decisions[item.sourceTrack.id] =
                            ReviewDecision.skip(
                          sourceTrackId: item.sourceTrack.id,
                        );
                      }),
                      onClear: () => setState(
                        () => _decisions.remove(item.sourceTrack.id),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: FilledButton.icon(
                  onPressed: _submitting ? null : () => _submit(items),
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    _submitting ? 'Enviando...' : 'Enviar revisión',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Review item card
// ---------------------------------------------------------------------------

enum _CardState { undecided, approved, skipped }

class _ReviewItemCard extends StatelessWidget {
  const _ReviewItemCard({
    required this.item,
    required this.decision,
    required this.onApprove,
    required this.onSkip,
    required this.onClear,
  });

  final ReviewPendingItem item;
  final ReviewDecision? decision;
  final void Function(String videoId) onApprove;
  final VoidCallback onSkip;
  final VoidCallback onClear;

  _CardState get _state {
    if (decision == null) return _CardState.undecided;
    return decision!.approve ? _CardState.approved : _CardState.skipped;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final best = item.bestOption;

    Color borderColor;
    switch (_state) {
      case _CardState.approved:
        borderColor = Colors.green;
      case _CardState.skipped:
        borderColor = Colors.grey;
      case _CardState.undecided:
        borderColor = cs.outlineVariant;
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Source track header
            Row(
              children: [
                const Icon(Icons.music_note_rounded, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.sourceTrack.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item.confidence.toInt()}%',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.orange),
                  ),
                ),
              ],
            ),
            Text(
              item.sourceTrack.displayArtists,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            if (item.sourceTrack.album != null)
              Text(
                item.sourceTrack.album!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
              ),

            if (best != null) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.smart_display_rounded, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      best.track.title,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Text(
                best.track.displayArtists,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],

            const SizedBox(height: 12),

            if (_state == _CardState.undecided)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onSkip,
                      icon: const Icon(Icons.skip_next_rounded, size: 16),
                      label: const Text('Omitir'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (best != null)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => onApprove(best.track.id),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Aprobar'),
                      ),
                    ),
                ],
              )
            else
              Row(
                children: [
                  Icon(
                    _state == _CardState.approved
                        ? Icons.check_circle_rounded
                        : Icons.skip_next_rounded,
                    size: 16,
                    color: _state == _CardState.approved
                        ? Colors.green
                        : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _state == _CardState.approved ? 'Aprobado' : 'Omitido',
                    style: TextStyle(
                      color: _state == _CardState.approved
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onClear,
                    child: const Text('Cambiar'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
