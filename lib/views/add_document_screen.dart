import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class AddDocumentScreen extends StatefulWidget {
  final Map<String, dynamic>? existingDoc;
  final String? parentId;
  const AddDocumentScreen({super.key, this.existingDoc, this.parentId});

  @override
  State<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends State<AddDocumentScreen> {
  final _nameController = TextEditingController();
  final _dateController = TextEditingController();
  final _customTypeController = TextEditingController();
  bool _notificationsEnabled = true;
  String _selectedType = 'Pasaporte';
  final List<String> _docTypes = [
    'Pasaporte',
    'Visa',
    'DNI',
    'Seguro',
    'Cédula',
    'Licencia de conducir',
    'Otro'
  ];
  // Definir la plantilla
  final dateMaskFormatter = MaskTextInputFormatter(
    mask: '##/##/####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  @override
  void initState() {
    super.initState();
    if (widget.existingDoc != null) {
      _nameController.text = widget.existingDoc!['name'] ?? '';
      _dateController.text = widget.existingDoc!['expiration_date'] ?? '';

      String savedType = widget.existingDoc!['doc_type'] ?? 'Pasaporte';

      // Si el tipo guardado no está en la lista predefinida, marcamos 'Otro'
      // y cargamos el valor en el controlador personalizado.
      if (!_docTypes.contains(savedType)) {
        _selectedType = 'Otro';
        _customTypeController.text = savedType;
      } else {
        _selectedType = savedType;
      }
      _notificationsEnabled = widget.existingDoc!['is_active'] == 1;
    }
  }

  // MÉTODO DE CAPTURA: Invocado por los botones del AppBar
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image != null) {
      final inputImage = InputImage.fromFilePath(image.path);
      _processImage(inputImage);
    }
  }

  // MÉTODO OCR: Procesa el texto detectado
  void _processImage(InputImage inputImage) async {
    final textRecognizer = TextRecognizer();
    final RecognizedText recognizedText =
        await textRecognizer.processImage(inputImage);

    // RegExp: Busca patrones de fecha (DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY)
    final RegExp dateRegExp =
        RegExp(r'(\d{1,2})[\s\./-](\d{1,2})[\s\./-](\d{2,4})');

    String? detectedDate;

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        String cleanText =
            line.text.replaceAll(RegExp(r'[^0-9/.\-]'), ' ').trim();
        final match = dateRegExp.firstMatch(cleanText);

        if (match != null) {
          String day = match.group(1)!.padLeft(2, '0');
          String month = match.group(2)!.padLeft(2, '0');
          String year = match.group(3)!;
          if (year.length == 2) {
            year = "20$year"; // Ajuste para años de 2 dígitos
          }
          detectedDate = "$day/$month/$year";
          break;
        }
      }
      if (detectedDate != null) break;
    }

    if (detectedDate != null) {
      setState(() => _dateController.text = detectedDate!);
    }
    textRecognizer.close();
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime initialDate = DateTime.now();

    // Si el usuario ya escribió algo válido, el calendario se abre en esa fecha
    if (_dateController.text.isNotEmpty) {
      try {
        initialDate = DateFormat('dd/MM/yyyy').parse(_dateController.text);
      } catch (e) {
        initialDate = DateTime.now();
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _saveDoc() async {
    if (_nameController.text.isEmpty || _dateController.text.isEmpty) return;

    final String docId = widget.existingDoc != null
        ? widget.existingDoc!['id']
        : const Uuid().v4();

    final String finalType = _selectedType == 'Otro'
        ? _customTypeController.text.trim()
        : _selectedType;

    try {
      DateFormat('dd/MM/yyyy').parse(_dateController.text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Formato de fecha inválido (DD/MM/YYYY)")),
      );
      return;
    }

    final data = {
      'id': docId,
      'name': _nameController.text,
      'type': 'document',
      'doc_type': finalType.isEmpty ? 'Otro' : finalType,
      'expiration_date': _dateController.text,
      'is_active':
          _notificationsEnabled ? 1 : 0, // Guarda la preferencia del usuario
      'parent_id': widget.parentId,
    };

    if (widget.existingDoc != null) {
      await DatabaseHelper.instance.updateItem(data);
    } else {
      await DatabaseHelper.instance.insertItem(data);
    }

    // Lógica de notificación condicionada al Switch
    if (_notificationsEnabled) {
      try {
        final expiry = DateFormat('dd/MM/yyyy').parse(_dateController.text);
        await NotificationService().scheduleExpirationNotice(
          id: docId,
          title: _nameController.text,
          expiryDate: expiry,
        );
      } catch (e) {
        debugPrint("Error fecha notificación: $e");
      }
    } else {
      // Si se desactiva, cancelamos cualquier notificación pendiente para este ID
      await NotificationService().cancelNotification(docId);
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingDoc == null
            ? "Nuevo Documento"
            : "Editar Documento"),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: () => _pickImage(ImageSource.gallery),
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: () => _pickImage(ImageSource.camera),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(
              controller: _dateController,
              keyboardType: TextInputType.number,
              inputFormatters: [dateMaskFormatter],
              decoration: InputDecoration(
                labelText: 'Vencimiento (DD/MM/YYYY)',
                // Muestra la fecha de hoy como ejemplo dinámico
                hintText: DateFormat('dd/MM/yyyy').format(DateTime.now()),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context),
                ),
              ),
            ),
            SwitchListTile(
              title: const Text("Activar recordatorio"),
              subtitle: const Text("Notificar 30 días antes del vencimiento"),
              value: _notificationsEnabled,
              onChanged: (bool value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
              secondary: const Icon(Icons.notifications_active),
            ),
            DropdownButton<String>(
              isExpanded: true,
              value: _selectedType,
              items: _docTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedType = val!),
            ),
            if (_selectedType == 'Otro') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _customTypeController,
                decoration: const InputDecoration(
                  labelText: 'Especifique el tipo de documento',
                  hintText: 'Ej: Carnet de Pesca',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _saveDoc, child: const Text("Guardar")),
          ],
        ),
      ),
    );
  }
}
