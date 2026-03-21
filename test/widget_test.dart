import 'package:flutter_test/flutter_test.dart';
import 'package:follow_docs/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Configura el motor de base de datos para entorno de pruebas
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('Carga de pantalla principal smoke test',
      (WidgetTester tester) async {
    // Carga la aplicación
    await tester.pumpWidget(const MyApp());

    // Verifica que el título de la aplicación o un texto base aparezca
    expect(find.text('Follow Docs'), findsOneWidget);
    expect(find.text('Principal'), findsOneWidget);
  });
}
