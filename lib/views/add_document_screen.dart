import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../services/database_helper.dart';
import '../services/ocr_service.dart';
import '../services/notification_service.dart';

class AddDocumentScreen extends StatefulWidget {
  final Map<String, dynamic>? existingDoc;
  const AddDocumentScreen({super.key, this.existingDoc});

  @override
  State<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends State<AddDocumentScreen> {
  final TextEditingController _nameController =
      TextEditingController(text: "Nuevo documento");
  final TextEditingController _dateController = TextEditingController();
  String _selectedType = "Cédula";
  final List<String> _docTypes = [
    "Cédula",
    "Pasaporte",
    "DNI",
    "Licencia de conducir"
  ];
  final OCRService _ocrService = OCRService();

  // Modificar State para cargar datos existentes
  @override
  void initState() {
    super.initState();
    if (widget.existingDoc != null) {
      _nameController.text = widget.existingDoc!['name'];
      _dateController.text = widget.existingDoc!['expiration_date'];
      _selectedType = widget.existingDoc!['doc_type'];
    }
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (picked != null) {
      setState(
          () => _dateController.text = DateFormat('dd/MM/yyyy').format(picked));
    }
  }

  Future<void> _scanWithCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (image == null) return;
    final result = await _ocrService.scanDocument(image.path);
    if (!mounted) return;
    setState(() {
      if (result['suggestedType'] != null) {
        _selectedType = result['suggestedType'];
      }
      if (result['expiryDate'] != null) {
        _dateController.text =
            DateFormat('dd/MM/yyyy').format(result['expiryDate']);
      }
    });
  }

// Modificar método _saveFollowDoc para alternar entre INSERT y UPDATE
  Future<void> _saveFollowDoc() async {
    if (_nameController.text.isEmpty || _dateController.text.isEmpty) return;

    final Map<String, dynamic> data = {
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

    // Programación de notificación (Lógica ya verificada anteriormente)
    try {
      final DateTime expiry =
          DateFormat('dd/MM/yyyy').parse(_dateController.text);
      await NotificationService().scheduleExpirationNotice(
        id: docId,
        title: _nameController.text,
        expiryDate: expiry,
      );
    } catch (e) {
      debugPrint("Error en notificación: $e");
    }

    if (mounted) Navigator.pop(context, true);
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
                decoration: const InputDecoration(labelText: "Nombre")),
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              // Especificamos explícitamente el tipo de los items
              items: _docTypes.map((String type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedType = newValue;
                  });
                }
              },
              decoration: const InputDecoration(labelText: "Tipo de documento"),
            ),
            Row(
              children: [
                Expanded(
                    child: TextField(
                        controller: _dateController,
                        decoration:
                            const InputDecoration(labelText: "Vencimiento"))),
                IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _selectDate),
                IconButton(
                    icon: const Icon(Icons.camera_alt),
                    onPressed: _scanWithCamera),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: _saveFollowDoc,
                child: const Text("Guardar Seguimiento")),
          ],
        ),
      ),
    );
  }
}
