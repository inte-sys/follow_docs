import 'package:flutter_test/flutter_test.dart';

// Función de validación (la lógica que implementaremos)
bool isValidFolderName(String name) {
  if (name.length > 32 || name.isEmpty) return false;
  final RegExp validCharacters = RegExp(r'^[a-zA-Z0-9\s\-]+$');
  return validCharacters.hasMatch(name);
}

void main() {
  test('Validar nombre de carpeta - Límite 32 caracteres', () {
    expect(isValidFolderName('Mi Carpeta de Documentos 2024'), true);
    expect(
      isValidFolderName('Esta es una carpeta con un nombre demasiado largo'),
      false,
    );
  });

  test('Validar nombre de carpeta - Caracteres permitidos', () {
    expect(isValidFolderName('Docs-Personales 01'), true);
    expect(
      isValidFolderName('Docs_Personales!'),
      false,
    ); // El guion bajo y ! no están permitidos
  });
}
