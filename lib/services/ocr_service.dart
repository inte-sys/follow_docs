import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// class OCRService {
//   final TextRecognizer _textRecognizer = TextRecognizer();

//   Future<Map<String, dynamic>> scanDocument(String imagePath) async {
//     final inputImage = InputImage.fromFilePath(imagePath);
//     final RecognizedText recognizedText =
//         await _textRecognizer.processImage(inputImage);

//     String fullText = recognizedText.text;
//     String? suggestedType;
//     DateTime? suggestedExpiryDate;

//     // Identificar tipo de documento
//     if (fullText.contains(
//         RegExp(r'DNI|Cédula|Pasaporte|Licencia', caseSensitive: false))) {
//       suggestedType = _inferDocumentType(fullText);
//     }

//     // Buscar patrones de fecha de vencimiento
//     suggestedExpiryDate = _extractExpirationDate(fullText);

//     return {
//       'text': fullText,
//       'suggestedType': suggestedType,
//       'expiryDate': suggestedExpiryDate,
//     };
//   }

//   String? _inferDocumentType(String text) {
//     if (text.contains(RegExp(r'Licencia', caseSensitive: false))) {
//       return "Licencia de conducir";
//     }
//     if (text.contains(RegExp(r'Pasaporte', caseSensitive: false))) {
//       return "Pasaporte";
//     }
//     if (text.contains(RegExp(r'DNI|Cédula', caseSensitive: false))) {
//       return "DNI/Cédula";
//     }
//     return null;
//   }

//   DateTime? _extractExpirationDate(String text) {
//     // Busca patrones comunes de fechas (DD/MM/AAAA o similares)
//     // cercanos a palabras clave como "Vence" o "Expiración"
//     final dateRegExp = RegExp(r'(\d{2}/\d{2}/\d{4})');
//     final match = dateRegExp.firstMatch(text);
//     if (match != null) {
//       try {
//         // Lógica simplificada para el MVP
//         return DateTime.parse(match.group(0)!.split('/').reversed.join('-'));
//       } catch (_) {
//         return null;
//       }
//     }
//     return null;
//   }

//   void dispose() {
//     _textRecognizer.close();
//   }
// }

class OCRService {
  // Usamos el script latino para documentos en español/inglés
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<Map<String, String?>> analyzeDocument(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);
      final String fullText = recognizedText.text.toLowerCase();

      // 1. Buscar Fecha de Vencimiento
      final RegExp dateRegExp = RegExp(r'(\d{2}[/\-. ]\d{2}[/\-. ]\d{4})');
      Iterable<RegExpMatch> matches = dateRegExp.allMatches(fullText);
      String? detectedDate = matches.isNotEmpty ? matches.last.group(0) : null;

      // 2. Determinar Tipo de Documento por palabras clave
      String? detectedType;
      if (fullText.contains('pasaporte') || fullText.contains('passport')) {
        detectedType = 'Pasaporte';
      } else if (fullText.contains('licencia') ||
          fullText.contains('license') ||
          fullText.contains('conducir')) {
        detectedType = 'Licencia';
      } else if (fullText.contains('visa')) {
        detectedType = 'Visa';
      } else if (fullText.contains('seguro') ||
          fullText.contains('insurance') ||
          fullText.contains('póliza')) {
        detectedType = 'Seguro';
      }

      return {
        'date': detectedDate,
        'type': detectedType,
      };
    } catch (e) {
      return {'date': null, 'type': null};
    }
  }

  // IMPORTANTE: Llamar a esto cuando ya no se use el servicio
  void dispose() {
    _textRecognizer.close();
  }
}
