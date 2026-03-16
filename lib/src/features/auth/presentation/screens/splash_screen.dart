import 'package:flutter/material.dart';

/// Pantalla de carga centralizada.
/// Usada por [AuthWrapper] (verificando sesión) y [LoginScreen] (procesando login).
class SplashScreen extends StatelessWidget {
  final String? message;

  const SplashScreen({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            if (message != null) ...[
              const SizedBox(height: 24),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
