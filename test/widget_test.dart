import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_docs/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Inicializamos la base de datos para el entorno de pruebas
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('Validación de flujo: Inicio y Buscador',
      (WidgetTester tester) async {
    // 1. Cargamos la aplicación
    await tester.pumpWidget(const MyApp());

    // 2. Avanzamos frames manualmente para permitir que InitializerScreen termine
    // Procesamos 10 saltos de medio segundo cada uno
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    // 3. Esperamos a que todas las animaciones se asienten
    await tester.pumpAndSettle();

    // 4. Verificación con RegExp (insensible a mayúsculas)
    // Buscamos cualquier widget que contenga la palabra "Principal"
    final homeTitle =
        find.textContaining(RegExp(r'follow docs', caseSensitive: false));
    expect(homeTitle, findsAtLeast(1),
        reason: "No se encontró la pantalla principal tras la carga");

    // 5. Simular apertura del buscador (clic en el icono de la lupa)
    final searchIcon = find.byIcon(Icons.search);
    if (searchIcon.evaluate().isNotEmpty) {
      await tester.tap(searchIcon);
      await tester.pumpAndSettle();

      // 6. Escribir en el buscador para validar que responda
      await tester.enterText(find.byType(TextField), 'Test');
      await tester.pump();

      expect(find.text('Test'), findsOneWidget);
    }
  });
}

// tests separados
// void main() {
//   TestWidgetsFlutterBinding.ensureInitialized();
//   sqfliteFfiInit(); // [cite: 1]
//   databaseFactory = databaseFactoryFfi; // [cite: 2]

//   // PRUEBA 1: Carga de Pantalla Principal (La que está fallando)
//   testWidgets('1. Carga de Pantalla Principal', (WidgetTester tester) async {
//     await tester.pumpWidget(const MyApp()); // [cite: 2]

//     // Reemplazamos el bucle y pumpAndSettle para evitar el timeout
//     await tester.pump(const Duration(seconds: 5));

//     debugPrint("=== DIAGNÓSTICO PANTALLA PRINCIPAL ===");
//     debugDumpApp(); // [cite: 3]

//     final homeTitle = find
//         .textContaining(RegExp(r'Todos', caseSensitive: false)); // [cite: 4]
//     expect(homeTitle, findsAtLeast(1)); // [cite: 4]
//   });

//   // PRUEBA 2: Apertura del Buscador
//   testWidgets('2. Apertura del Buscador', (WidgetTester tester) async {
//     await tester.pumpWidget(const MyApp());
//     await tester.pumpAndSettle();

//     final searchIcon = find.byIcon(Icons.search); // [cite: 4]
//     if (searchIcon.evaluate().isNotEmpty) {
//       // [cite: 5]
//       await tester.tap(searchIcon); // [cite: 5]
//       await tester.pumpAndSettle();
//     }
//   });

//   // PRUEBA 3: Escritura en Buscador
//   testWidgets('3. Escritura en Buscador', (WidgetTester tester) async {
//     await tester.pumpWidget(const MyApp());
//     await tester.pumpAndSettle();

//     // Asumimos que el buscador está abierto o lo abrimos rápido
//     final searchIcon = find.byIcon(Icons.search);
//     if (searchIcon.evaluate().isNotEmpty) {
//       await tester.tap(searchIcon);
//       await tester.pumpAndSettle();

//       await tester.enterText(find.byType(TextField), 'Test'); // [cite: 6]
//       await tester.pumpAndSettle(); // [cite: 6]
//       expect(find.text('Test'), findsOneWidget); // [cite: 7]
//     }
//   });
// }
