import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:uuid/uuid.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/ocr_service.dart';
import 'camera_scanner_screen.dart';

class AddDocumentScreen extends StatefulWidget {
  final Map<String, dynamic>? existingDoc;
  final String? parentId;

  const AddDocumentScreen({super.key, this.existingDoc, this.parentId});

  @override
  State<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends State<AddDocumentScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _customTypeController = TextEditingController();

  String _selectedType = 'Pasaporte';
  bool _notificationsEnabled = true;

  final List<String> _docTypes = [
    'Pasaporte',
    'Licencia',
    'Visa',
    'Seguro',
    'Otro'
  ];

  final dateMaskFormatter = MaskTextInputFormatter(
    mask: '##/##/####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void initState() {
    super.initState();
    // Carga de datos inicial si se trata de una edición
    if (widget.existingDoc != null) {
      _nameController.text = widget.existingDoc!['name'] ?? '';
      _dateController.text = widget.existingDoc!['expiration_date'] ?? '';

      final savedType = widget.existingDoc!['doc_type'] ?? 'Pasaporte';
      if (_docTypes.contains(savedType)) {
        _selectedType = savedType;
      } else {
        _selectedType = 'Otro';
        _customTypeController.text = savedType;
      }

      _notificationsEnabled = widget.existingDoc!['is_active'] == 1;
    }
  }

  /// Guarda el documento en la base de datos y programa la alerta si es necesario
  Future<void> _saveDoc() async {
    if (_nameController.text.isEmpty || _dateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor rellena todos los campos")),
      );
      return;
    }

    // Validación rigurosa de la fecha
    try {
      DateFormat('dd/MM/yyyy').parse(_dateController.text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Formato de fecha inválido (DD/MM/AAAA)")),
      );
      return;
    }

    final String docId = widget.existingDoc != null
        ? widget.existingDoc!['id']
        : const Uuid().v4();

    final String finalType = _selectedType == 'Otro'
        ? _customTypeController.text.trim()
        : _selectedType;

    final Map<String, dynamic> data = {
      'id': docId,
      'name': _nameController.text,
      'type': 'document',
      'doc_type': finalType.isEmpty ? 'Otro' : finalType,
      'expiration_date': _dateController.text,
      'is_active': _notificationsEnabled ? 1 : 0,
      'parent_id': widget.parentId,
    };

    // Operación en la base de datos
    if (widget.existingDoc != null) {
      await DatabaseHelper.instance.updateItem(data);
    } else {
      await DatabaseHelper.instance.insertItem(data);
    }

    // Programación de la notificación 7 días antes del vencimiento
    if (_notificationsEnabled) {
      try {
        final DateTime expiry =
            DateFormat('dd/MM/yyyy').parse(_dateController.text);

        await NotificationService().scheduleNotification(
          id: docId.hashCode,
          title: "Vencimiento Próximo",
          body:
              "Tu ${finalType.toLowerCase()} '${_nameController.text}' vence en 7 días.",
          scheduledDate: expiry,
        );
      } catch (e) {
        debugPrint("Error al programar notificación: $e");
      }
    } else {
      // Cancelar si el usuario desactiva los recordatorios
      await NotificationService().cancelNotification(docId.hashCode.toString());
    }

    if (mounted) Navigator.pop(context, true);
  }

  /// Inicia el flujo de cámara y procesa los resultados con OCR
  Future<void> _pickAndScanImage() async {
    final String? imagePath = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraScannerScreen()),
    );

    if (imagePath != null) {
      final ocr = OCRService();
      // El servicio ahora devuelve tanto la fecha como la categoría detectada
      final result = await ocr.analyzeDocument(imagePath);
      ocr.dispose();

      setState(() {
        if (result['date'] != null) {
          _dateController.text = result['date']!;
        }

        if (result['type'] != null) {
          final String detected = result['type']!;
          if (_docTypes.contains(detected)) {
            _selectedType = detected;
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result['type'] != null
                ? "Identificado como: ${result['type']}"
                : "Datos extraídos con éxito")),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _customTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingDoc == null
            ? 'Nuevo Documento'
            : 'Editar Documento'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveDoc,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del documento',
                hintText: 'Ej: Pasaporte de Luis',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedType,
              items: _docTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedType = val!),
              decoration: const InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(),
              ),
            ),
            if (_selectedType == 'Otro') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _customTypeController,
                decoration: const InputDecoration(
                  labelText: 'Tipo personalizado',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _dateController,
              inputFormatters: [dateMaskFormatter],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Fecha de Vencimiento (DD/MM/AAAA)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: _pickAndScanImage,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text("Notificaciones automáticas"),
              subtitle: const Text("Avisar 7 días antes de expirar"),
              value: _notificationsEnabled,
              onChanged: (val) => setState(() => _notificationsEnabled = val),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saveDoc,
                icon: const Icon(Icons.save),
                label: const Text("GUARDAR DATOS"),
              ),
            )
          ],
        ),
      ),
    );
  }
}
