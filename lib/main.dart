import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Importa Riverpod
import 'package:google_sign_in/google_sign_in.dart';
import 'package:keepsyn_app/src/features/auth/presentation/screens/auth_wrapper.dart';
import 'firebase_options.dart';

// Clave interna
const serverClientId = String.fromEnvironment('SERVER_CLIENT_ID');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Validación si la clave está presente
  if (serverClientId.isEmpty) {
    throw Exception(
      'ERROR: La variable SERVER_CLIENT_ID no fue proporcionada.',
    );
  }

  // Usa la instancia singleton para inicializar
  await GoogleSignIn.instance.initialize(serverClientId: serverClientId);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KeepSyn',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AuthWrapper(),
    );
  }
}
