import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart'; // Para generar IDs únicos (agrega 'uuid' al pubspec)
import '../services/ocr_service.dart';
// Importa el helper y el modelo al inicio del archivo
import '../services/database_helper.dart';

class AddDocumentScreen extends StatefulWidget {
  const AddDocumentScreen({super.key});

  @override
  State<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends State<AddDocumentScreen> {
  //  Valor predeterminado sugerido
  final TextEditingController _nameController =
      TextEditingController(text: "Nuevo documento");
  final TextEditingController _dateController = TextEditingController();

  // [cite: 21] Valores por defecto para el tipo de documento
  String _selectedType = "Cédula";
  final List<String> _docTypes = [
    "Cédula",
    "Pasaporte",
    "DNI",
    "Licencia de conducir"
  ];

  final OCRService _ocrService = OCRService();

  // Selección por Calendario
  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  // [cite: 25] Integración con OCR
  Future<void> _scanWithCamera() async {
    // Aquí se llamaría a la cámara y luego al servicio OCR
    // Por ahora, simulamos la respuesta del servicio definido anteriormente
    final result = await _ocrService.scanDocument("path_to_image");

    setState(() {
      if (result['suggestedType'] != null) {
        _selectedType = result['suggestedType']; //
      }
      if (result['expiryDate'] != null) {
        _dateController.text =
            DateFormat('dd/MM/yyyy').format(result['expiryDate']); //
      }
    });
  }

  Future<void> _saveFollowDoc() async {
    if (_nameController.text.isEmpty || _dateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Por favor, completa el nombre y la fecha")),
      );
      return;
    }

    // Preparar el mapa de datos siguiendo tu modelo de DB
    final newItem = {
      'id': const Uuid().v4(),
      'name': _nameController.text,
      'type': 'document',
      'doc_type': _selectedType,
      'expiration_date': _dateController.text, // Idealmente convertir a ISO8601
      'reminder_type': 'notification', // Regla: notificación por defecto
      'reminder_value': 1, // Regla: 1
      'reminder_unit': 'meses', // Regla: mes antes
      'is_active': 1,
    };

    await DatabaseHelper.instance.insertItem(newItem);

    if (mounted) {
      Navigator.pop(
          context, true); // Regresar a la Home y avisar que hubo cambios
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nuevo Documento")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration:
                  const InputDecoration(labelText: "Nombre del documento"),
            ),
            DropdownButtonFormField(
              initialValue: _selectedType,
              items: _docTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedType = val as String),
              decoration: const InputDecoration(labelText: "Tipo de documento"),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                        labelText: "Fecha de vencimiento (DD/MM/AAAA)"),
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _selectDate), //
                IconButton(
                    icon: const Icon(Icons.camera_alt),
                    onPressed: _scanWithCamera), //
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              // onPressed: () {/* Lógica para guardar en BD Local  */},
              onPressed: _saveFollowDoc,
              child: const Text("Guardar Seguimiento"),
            )
          ],
        ),
      ),
    );
  }
}
