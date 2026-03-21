import 'package:flutter/material.dart';
import 'views/home_screen.dart'; // Importa tu pantalla principal
import 'services/notification_service.dart';

void main() async {
  // Asegura que los bindings de Flutter estén listos (necesario para SQLite)
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
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
        useMaterial3: true,
        // Paleta de colores: Azul Profundo y detalles en Cian
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E),
          primary: const Color(0xFF1A237E),
          secondary: const Color(0xFF00B8D4),
          surface: const Color(0xFFF5F5F5),
        ),
        // Estilo de la AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A237E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        // Estilo de las tarjetas (Card)
        cardTheme: CardThemeData(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 4),
        ),
        // Estilo del botón flotante
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF00B8D4),
          foregroundColor: Colors.white,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
