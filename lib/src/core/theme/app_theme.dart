import 'package:flutter/material.dart';

/// Tema centralizado de la aplicación.
/// Úsalo en MaterialApp: theme: AppTheme.light, darkTheme: AppTheme.dark.
class AppTheme {
  AppTheme._();

  static const _seedColor = Colors.deepPurple;

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
  );
}

