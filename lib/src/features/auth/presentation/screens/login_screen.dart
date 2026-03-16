import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keepsyn_app/src/core/error/failures.dart';
import 'package:keepsyn_app/src/features/auth/presentation/riverpod/auth_providers.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.sync_rounded, size: 72, color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'KeepSyn',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sincroniza tus playlists entre plataformas',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),
              if (authState.hasError) ...[
                _ErrorBanner(
                  failure: authState.failure,
                  onDismiss: () =>
                      ref.read(authControllerProvider.notifier).clearFailure(),
                ),
                const SizedBox(height: 24),
              ],
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: authState.isSubmitting
                    ? null
                    : () => ref
                    .read(authControllerProvider.notifier)
                    .signInWithGoogle(),
                icon: authState.isSubmitting
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.login),
                label: Text(
                  authState.isSubmitting
                      ? 'Iniciando sesión...'
                      : 'Continuar con Google',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final Failure? failure;
  final VoidCallback onDismiss;

  const _ErrorBanner({
    required this.failure,
    required this.onDismiss,
  });

  String _resolveMessage() {
    if (failure is UnauthorizedFailure) {
      return failure?.message ?? 'Tu cuenta no está autorizada para acceder.';
    }
    if (failure is SignInCancelledFailure) {
      return 'Inicio de sesión cancelado.';
    }
    return failure?.message ?? 'Ocurrió un error. Intenta de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUnauthorized = failure is UnauthorizedFailure;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnauthorized
            ? colorScheme.errorContainer
            : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnauthorized ? colorScheme.error : colorScheme.secondary,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isUnauthorized ? Icons.block_rounded : Icons.info_outline_rounded,
            color: isUnauthorized ? colorScheme.error : colorScheme.secondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _resolveMessage(),
              style: TextStyle(
                color: isUnauthorized
                    ? colorScheme.onErrorContainer
                    : colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: isUnauthorized
                ? colorScheme.onErrorContainer
                : colorScheme.onSecondaryContainer,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
