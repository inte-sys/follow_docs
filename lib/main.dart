import 'package:flutter/material.dart';
import 'views/home_screen.dart'; // Importa tu pantalla principal

void main() {
  // Asegura que los bindings de Flutter estén listos (necesario para SQLite)
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FollowDocsApp());
}

class FollowDocsApp extends StatelessWidget {
  const FollowDocsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Follow Docs',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(), // <--- Aquí llamamos a tu pantalla
    );
  }
}
