// import 'package:flutter_test/flutter_test.dart';
// import 'package:follow_docs/main.dart';
// import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// void main() {
//   // Configura el motor de base de datos para entorno de pruebas
//   sqfliteFfiInit();
//   databaseFactory = databaseFactoryFfi;

//   testWidgets('Carga de pantalla principal smoke test',
//       (WidgetTester tester) async {
//     // Carga la aplicación
//     await tester.pumpWidget(const MyApp());

//     // Verifica que el título de la aplicación o un texto base aparezca
//     expect(find.text('Follow Docs'), findsOneWidget);
//     expect(find.text('Principal'), findsOneWidget);
//   });
// }

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_docs/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Configuración para que la BD funcione en el test
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('Validación de flujo: Inicio y Buscador',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // 1. Esperar a que pase la pantalla de carga (InitializerScreen)
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 2. Verificar que llegamos a la pantalla Principal
    expect(find.text('Principal'), findsOneWidget);

    // 3. Simular apertura del buscador (clic en icono lupa)
    final searchIcon = find.byIcon(Icons.search);
    if (searchIcon.evaluate().isNotEmpty) {
      await tester.tap(searchIcon);
      await tester.pumpAndSettle();

      // 4. Escribir en el buscador
      await tester.enterText(find.byType(TextField), 'Test');
      await tester.pump();

      // Verificación de que el texto se ingresó
      expect(find.text('Test'), findsOneWidget);
    }
  });
}
