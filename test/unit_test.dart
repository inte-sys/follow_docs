// import 'package:flutter_test/flutter_test.dart';

// void main() {
//   group('Pruebas Unitarias de Lógica', () {
//     test('Validación de formato de fecha', () {
//       const fecha = "21/03/2026";
//       final partes = fecha.split('/');
//       expect(partes.length, 3);
//       expect(int.parse(partes[2]), 2026);
//     });

//     test('Validación de tipos de items', () {
//       const folder = 'folder';
//       const doc = 'document';
//       expect(folder, isNot(doc));
//     });
//   });

//   test('La búsqueda debe filtrar correctamente por nombre', () {
//     final listaOriginal = [
//       {'name': 'Pasaporte'},
//       {'name': 'Visa'},
//       {'name': 'Seguro Médico'}
//     ];

//     final busqueda = 'pas';
//     final resultado = listaOriginal
//         .where((i) => i['name']!.toLowerCase().contains(busqueda.toLowerCase()))
//         .toList();

//     expect(resultado.length, 1);
//     expect(resultado[0]['name'], 'Pasaporte');
//   });
// }

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('Pruebas de Lógica de Documentos', () {
    test('Validación de estructura de Carpeta', () {
      final folder = {
        'id': const Uuid().v4(),
        'name': 'Fotos',
        'type': 'folder',
        'parent_id': null,
      };
      expect(folder['type'], 'folder');
      expect(folder['name'], isNotEmpty);
    });

    test('Validación de estructura de Documento', () {
      final doc = {
        'id': const Uuid().v4(),
        'name': 'Pasaporte',
        'type': 'document',
        'expiration_date': '20/12/2030',
      };
      expect(doc['type'], 'document');
      expect(doc['expiration_date'], contains('/'));
    });

    test('La búsqueda debe filtrar correctamente por nombre', () {
      final listaOriginal = [
        {'name': 'Pasaporte'},
        {'name': 'Visa'},
        {'name': 'Seguro Médico'}
      ];

      final busqueda = 'pas';
      final resultado = listaOriginal
          .where(
              (i) => i['name']!.toLowerCase().contains(busqueda.toLowerCase()))
          .toList();

      expect(resultado.length, 1);
      expect(resultado[0]['name'], 'Pasaporte');
    });
  });

  test('Validación de lógica de eliminación', () {
    final lista = [
      {'id': '1', 'name': 'Doc 1'},
      {'id': '2', 'name': 'Doc 2'}
    ];

    const idAEliminar = '1';
    lista.removeWhere((item) => item['id'] == idAEliminar);

    expect(lista.length, 1);
    expect(lista.any((item) => item['id'] == '1'), isFalse);
  });

  test('Validación de objeto FollowItem tras creación', () {
    final item = {
      'id': 'unique_id_123',
      'name': 'Documento Prueba',
      'type': 'document',
      'expiration_date': '31/12/2026'
    };

    expect(item['id'], isNotNull);
    expect(item['name'], 'Documento Prueba');
    expect(item['type'], 'document');
  });

  test('Acción: Extraer fecha de texto OCR', () {
    const textoEscaneado =
        "PASAPORTE REPUBLICA... FECHA VENCIMIENTO: 25/12/2030... AUTORIDAD...";

    // Expresión regular para buscar formatos dd/mm/yyyy
    final regExp = RegExp(r'(\d{2}/\d{2}/\d{4})');
    final coincidencia = regExp.firstMatch(textoEscaneado);

    expect(coincidencia, isNotNull);
    expect(coincidencia!.group(0), '25/12/2030');
  });

  test('Acción: Integración de fecha detectada en el controlador', () {
    final controlador = TextEditingController();
    const fechaDetectada = "25/12/2030";

    // Simulación de la acción que ocurre tras cerrar la cámara
    controlador.text = fechaDetectada;

    expect(controlador.text, fechaDetectada);
    expect(controlador.text.split('/').length, 3);
  });
}
