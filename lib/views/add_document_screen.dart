import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
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

  void _processImage(InputImage inputImage) async {
    final textRecognizer = TextRecognizer();
    final RecognizedText recognizedText =
        await textRecognizer.processImage(inputImage);

    // Patrón que acepta DD/MM/YYYY, DD.MM.YYYY, DD MM YYYY y formatos de 2 dígitos en año
    final RegExp dateRegExp =
        RegExp(r'(\d{1,2})[\s\./-](\d{1,2})[\s\./-](\d{2,4})');

    String? detectedDate;
    String? detectedName;

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        String text = line.text.trim();

        // 1. BUSCAR FECHA: Limpiamos ruido visual (ej: "EXP: 12/10/2025" -> "12/10/2025")
        final match = dateRegExp.firstMatch(text);
        if (match != null) {
          String day = match.group(1)!.padLeft(2, '0');
          String month = match.group(2)!.padLeft(2, '0');
          String year = match.group(3)!;

          // Convertir años de 2 dígitos (ej: 25 -> 2025)
          if (year.length == 2) year = "20$year";

          // Validación básica: no asignar fechas imposibles (ej: día > 31)
          int d = int.parse(day);
          int m = int.parse(month);
          if (d > 0 && d <= 31 && m > 0 && m <= 12) {
            detectedDate = "$day/$month/$year";
          }
        }

        // 2. BUSCAR NOMBRE: Si la línea tiene palabras largas y el controlador está vacío
        if (detectedName == null &&
            _nameController.text.isEmpty &&
            text.length > 5 &&
            !text.contains(RegExp(r'\d'))) {
          detectedName = text;
        }
      }
    }

    setState(() {
      if (detectedDate != null) {
        _dateController.text = detectedDate!;
      }
      if (detectedName != null) {
        _nameController.text = detectedName!;
      }
    });

    textRecognizer.close();

    if (detectedDate == null) {
      debugPrint("OCR: No se detectó una fecha válida.");
    }
  }

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

  // 1. EL MÉTODO (Asegúrate de que esté así)
  // Dentro del método build o donde invoques la cámara/galería:
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image != null) {
      final inputImage = InputImage.fromFilePath(image.path);
      _processImage(inputImage); // Llamada al método actualizado arriba
    }
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
      appBar: AppBar(
        title: Text(widget.existingDoc == null
            ? "Nuevo Documento"
            : "Editar Documento"),
        actions: [
          // Botón para abrir la Galería
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: () => _pickImage(ImageSource.gallery),
            tooltip: "Escanear desde Galería",
          ),
          // Botón para abrir la Cámara
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: () => _pickImage(ImageSource.camera),
            tooltip: "Escanear con Cámara",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Campo para el nombre del documento
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Documento',
                  hintText: 'Ej: Pasaporte, Visa, Seguro',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Selector de tipo de documento
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: ['Pasaporte', 'Visa', 'Identificación', 'Otro']
                    .map((label) => DropdownMenuItem(
                          value: label,
                          child: Text(label),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedType = value!);
                },
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Campo para la fecha (rellenado automáticamente por OCR)
              TextField(
                controller: _dateController,
                readOnly:
                    true, // Evita escritura manual para usar el picker o OCR
                decoration: const InputDecoration(
                  labelText: 'Fecha de Vencimiento',
                  hintText: 'DD/MM/YYYY',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                onTap: () async {
                  // Opción de respaldo: Selector de fecha manual
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _dateController.text =
                          DateFormat('dd/MM/yyyy').format(pickedDate);
                    });
                  }
                },
              ),
              const SizedBox(height: 30),

              // Botón de Guardar
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveFollowDoc,
                  child: Text(
                      widget.existingDoc == null ? "GUARDAR" : "ACTUALIZAR"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
