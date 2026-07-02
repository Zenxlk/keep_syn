import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:keepsyn_app/src/core/constants/env_constants.dart';
import 'package:keepsyn_app/src/core/logger/app_logger.dart';
import 'package:keepsyn_app/src/core/router/app_router.dart';
import 'package:keepsyn_app/src/core/theme/app_theme.dart';
import 'package:keepsyn_app/src/features/notifications/notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppLogger.info('Inicializando Firebase...', tag: 'main');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register background message handler before any other FCM setup.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  if (EnvConstants.serverClientId.isEmpty) {
    AppLogger.error('SERVER_CLIENT_ID no proporcionado.', tag: 'main');
    throw Exception('ERROR: La variable SERVER_CLIENT_ID no fue proporcionada.');
  }

  AppLogger.info('Inicializando GoogleSignIn...', tag: 'main');
  await GoogleSignIn.instance.initialize(
    serverClientId: EnvConstants.serverClientId,
  );

  runApp(const ProviderScope(child: KeepSynApp()));
}

class KeepSynApp extends ConsumerWidget {
  const KeepSynApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'KeepSyn',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
