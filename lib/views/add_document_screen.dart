import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../services/database_helper.dart';
import '../services/ocr_service.dart';

class AddDocumentScreen extends StatefulWidget {
  const AddDocumentScreen({super.key});

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

  Future<void> _saveFollowDoc() async {
    if (_nameController.text.isEmpty || _dateController.text.isEmpty) return;
    await DatabaseHelper.instance.insertItem({
      'id': const Uuid().v4(),
      'name': _nameController.text,
      'type': 'document',
      'doc_type': _selectedType,
      'expiration_date': _dateController.text,
      'is_active': 1,
    });
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
              value: _selectedType,
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
