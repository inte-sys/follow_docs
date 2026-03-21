import 'package:flutter/material.dart';
import 'services/database_helper.dart';
import 'services/notification_service.dart';
import 'views/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Follow Docs',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E),
          primary: const Color(0xFF1A237E),
          secondary: const Color(0xFF00B8D4),
        ),
      ),
      home: const InitializerScreen(),
    );
  }
}

class InitializerScreen extends StatefulWidget {
  const InitializerScreen({super.key});

  @override
  State<InitializerScreen> createState() => _InitializerScreenState();
}

class _InitializerScreenState extends State<InitializerScreen> {
  String _statusMessage = "Iniciando sistema...";
  bool _hasError = false;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // 1. Base de datos (Crítico)
      setState(() => _statusMessage = "Configurando base de datos...");
      await DatabaseHelper.instance.database;

      // 2. Notificaciones (No crítico para el arranque)
      setState(() => _statusMessage = "Sincronizando notificaciones...");
      try {
        // Le damos un margen para que intente inicializar
        await NotificationService().init().timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint("Notificaciones fallaron al iniciar, pero continuando...");
      }

      // Navegar a la Home
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _statusMessage = "Error en el arranque";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        // Eliminamos padding de aquí y envolvemos el hijo en un Padding
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.description, size: 80, color: Color(0xFF1A237E)),
              const SizedBox(height: 24),
              if (!_hasError) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(_statusMessage, textAlign: TextAlign.center),
              ] else ...[
                const Icon(Icons.error_outline, size: 50, color: Colors.red),
                const SizedBox(height: 16),
                Text(_statusMessage,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 8),
                Text(_errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => _initializeApp(),
                  child: const Text("Reintentar"),
                )
              ],
            ],
          ),
        ),
      ),
    );
  }
}
