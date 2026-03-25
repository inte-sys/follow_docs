import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _notifValueController =
      TextEditingController(text: '7');

  String _selectedType = 'Pasaporte';
  bool _notificationsEnabled = true;
  String _notifUnit = 'Días';

  final List<String> _unitOptions = ['Días', 'Semanas', 'Meses'];
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
    if (widget.existingDoc != null) {
      _nameController.text = widget.existingDoc!['name'] ?? '';
      _dateController.text = widget.existingDoc!['expiration_date'] ?? '';

      int savedValue = widget.existingDoc!['notif_value'] ?? 0;
      _notifUnit = widget.existingDoc!['notif_unit'] ?? 'Días';

      if (savedValue > 0) {
        _notifValueController.text = savedValue.toString();
        _notificationsEnabled = true;
      } else {
        _notifValueController.text = '7';
        _notificationsEnabled = false;
      }

      final savedType = widget.existingDoc!['doc_type'] ?? 'Pasaporte';
      if (_docTypes.contains(savedType)) {
        _selectedType = savedType;
      } else {
        _selectedType = 'Otro';
        _customTypeController.text = savedType;
      }
    }
  }

  bool _validateNotifLimits(int value) {
    if (!_notificationsEnabled) return true;

    // Límite unificado a 1 año para todas las unidades
    if (_notifUnit == 'Días' && value > 365) {
      _showError("El límite es 365 días (1 año)");
      return false;
    }
    if (_notifUnit == 'Semanas' && value > 52) {
      _showError("El límite es 52 semanas (1 año)");
      return false;
    }
    if (_notifUnit == 'Meses' && value > 12) {
      _showError("El límite es 12 meses (1 año)");
      return false;
    }
    return true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _saveDoc() async {
    if (_nameController.text.isEmpty || _dateController.text.isEmpty) {
      _showError("Rellena nombre y fecha");
      return;
    }

    DateTime expiryDate;
    try {
      expiryDate = DateFormat('dd/MM/yyyy').parse(_dateController.text);
    } catch (e) {
      _showError("Fecha inválida");
      return;
    }

    int notifValue = int.tryParse(_notifValueController.text) ?? 7;
    if (!_validateNotifLimits(notifValue)) return;

    int finalNotifValue = _notificationsEnabled ? notifValue : 0;
    int daysToSubtract = _notifUnit == 'Semanas'
        ? finalNotifValue * 7
        : (_notifUnit == 'Meses' ? finalNotifValue * 30 : finalNotifValue);

    final String docId = widget.existingDoc != null
        ? widget.existingDoc!['id']
        : const Uuid().v4();
    final String finalType = _selectedType == 'Otro'
        ? _customTypeController.text.trim()
        : _selectedType;

    final Map<String, dynamic> data = {
      'id': docId,
      'name': _nameController.text.trim(),
      'type': 'document',
      'doc_type': finalType.isEmpty ? 'Otro' : finalType,
      'expiration_date': _dateController.text,
      'is_active': 1,
      'parent_id': widget.parentId,
      'notif_value': finalNotifValue,
      'notif_unit': _notifUnit,
    };

    try {
      if (widget.existingDoc != null) {
        await DatabaseHelper.instance.updateItem(data);
      } else {
        await DatabaseHelper.instance.insertItem(data);
      }

      if (finalNotifValue > 0) {
        final alarmDate = expiryDate.subtract(Duration(days: daysToSubtract));
        if (alarmDate.isAfter(DateTime.now())) {
          await NotificationService().scheduleNotification(
            id: docId.hashCode,
            title: "Vencimiento Próximo",
            body:
                "Tu ${finalType.toLowerCase()} '${_nameController.text}' vence pronto.",
            scheduledDate: alarmDate,
          );
        }
      } else {
        await NotificationService().cancelNotification(docId);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showError("Error al guardar");
    }
  }

  Future<void> _pickAndScanImage() async {
    final String? imagePath = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraScannerScreen()),
    );

    if (imagePath != null) {
      final ocr = OCRService();
      final result = await ocr.analyzeDocument(imagePath);
      ocr.dispose();

      setState(() {
        if (result['date'] != null) _dateController.text = result['date']!;
        if (result['type'] != null && _docTypes.contains(result['type'])) {
          _selectedType = result['type']!;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _customTypeController.dispose();
    _notifValueController.dispose();
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
          IconButton(icon: const Icon(Icons.check), onPressed: _saveDoc)
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              maxLength: 64, // Límite de 64 caracteres
              decoration: const InputDecoration(
                  labelText: 'Nombre del documento',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedType,
              items: _docTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedType = val!),
              decoration: const InputDecoration(
                  labelText: 'Categoría', border: OutlineInputBorder()),
            ),
            if (_selectedType == 'Otro') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _customTypeController,
                maxLength: 20, // Límite de 20 caracteres
                decoration: const InputDecoration(
                    labelText: 'Tipo personalizado',
                    border: OutlineInputBorder()),
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
                    onPressed: _pickAndScanImage),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text("Notificaciones automáticas"),
              value: _notificationsEnabled,
              onChanged: (val) => setState(() => _notificationsEnabled = val),
            ),
            if (_notificationsEnabled)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8.0,
                  children: [
                    const Text("Avisar "),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: _notifValueController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(
                              3), // Máximo 3 dígitos
                        ],
                      ),
                    ),
                    DropdownButton<String>(
                      value: _notifUnit,
                      items: _unitOptions
                          .map(
                              (u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (val) => setState(() => _notifUnit = val!),
                    ),
                    const Text(" antes."),
                  ],
                ),
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
