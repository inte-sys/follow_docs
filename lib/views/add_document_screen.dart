import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';

class AddDocumentScreen extends StatefulWidget {
  final Map<String, dynamic>? existingDoc;
  const AddDocumentScreen({super.key, this.existingDoc});

  @override
  State<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends State<AddDocumentScreen> {
  final _nameController = TextEditingController();
  final _dateController = TextEditingController();
  String _selectedType = 'Pasaporte';
  final List<String> _docTypes = ['Pasaporte', 'Visa', 'DNI', 'Seguro', 'Otro'];

  @override
  void initState() {
    super.initState();
    if (widget.existingDoc != null) {
      _nameController.text = widget.existingDoc!['name'] ?? '';
      _dateController.text = widget.existingDoc!['expiration_date'] ?? '';
      _selectedType = widget.existingDoc!['doc_type'] ?? 'Pasaporte';
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

  Future<void> _saveDoc() async {
    if (_nameController.text.isEmpty || _dateController.text.isEmpty) return;

    final data = {
      'name': _nameController.text,
      'type': 'document',
      'doc_type': _selectedType,
      'expiration_date': _dateController.text,
      'is_active': 1,
    };

    String docId;
    if (widget.existingDoc != null) {
      docId = widget.existingDoc!['id'];
      data['id'] = docId;
      await DatabaseHelper.instance.updateItem(data);
    } else {
      docId = const Uuid().v4();
      data['id'] = docId;
      await DatabaseHelper.instance.insertItem(data);
    }

    // Notificación
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
                decoration: const InputDecoration(
                    labelText: 'Vencimiento (DD/MM/YYYY)')),
            DropdownButton<String>(
              value: _selectedType,
              items: _docTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedType = val!),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _saveDoc, child: const Text("Guardar")),
          ],
        ),
      ),
    );
  }
}
