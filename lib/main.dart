import 'package:flutter/material.dart';

// Importación de los paquetes de firebase
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Veirfica el estado de Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Firebase usando las opciones de la plataforma actual
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KeepSyn',
      home: Scaffold(
        appBar: AppBar(title: const Text('KeepSyn')),
        body: const Center(
          child: Text('Proyecto inicializado y conectado a Firebase! ✅'),
        ),
      ),
    );
  }
}
