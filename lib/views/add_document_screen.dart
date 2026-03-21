import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:uuid/uuid.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';

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

  String _selectedType = 'Pasaporte';
  bool _notificationsEnabled = true; // Estado del Switch

  final _docTypes = ['Pasaporte', 'Licencia', 'Visa', 'Seguro', 'Otro'];
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
      _notificationsEnabled = widget.existingDoc!['is_active'] == 1;

      String savedType = widget.existingDoc!['doc_type'] ?? 'Pasaporte';
      if (!_docTypes.contains(savedType)) {
        _selectedType = 'Otro';
        _customTypeController.text = savedType;
      } else {
        _selectedType = savedType;
      }
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
        const SnackBar(content: Text("Formato de fecha inválido")),
      );
      return;
    }

    final data = {
      'id': docId,
      'name': _nameController.text,
      'type': 'document',
      'doc_type': finalType.isEmpty ? 'Otro' : finalType,
      'expiration_date': _dateController.text,
      'is_active': _notificationsEnabled ? 1 : 0,
      'parent_id': widget.parentId,
    };

    if (widget.existingDoc != null) {
      await DatabaseHelper.instance.updateItem(data);
    } else {
      await DatabaseHelper.instance.insertItem(data);
    }

    if (_notificationsEnabled) {
      try {
        final expiry = DateFormat('dd/MM/yyyy').parse(_dateController.text);
        await NotificationService().scheduleExpirationNotice(
          id: docId,
          title: _nameController.text,
          expiryDate: expiry,
        );
      } catch (e) {
        debugPrint("Error notificación: $e");
      }
    } else {
      await NotificationService().cancelNotification(docId);
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Detalles del Documento")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration:
                  const InputDecoration(labelText: 'Nombre del documento'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              items: _docTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedType = val!),
              decoration: const InputDecoration(labelText: 'Tipo'),
            ),
            if (_selectedType == 'Otro') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _customTypeController,
                decoration:
                    const InputDecoration(labelText: 'Especifique tipo'),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _dateController,
              keyboardType: TextInputType.number,
              inputFormatters: [dateMaskFormatter],
              decoration: InputDecoration(
                labelText: 'Vencimiento (DD/MM/YYYY)',
                hintText: DateFormat('dd/MM/yyyy').format(DateTime.now()),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text("Activar recordatorio"),
              subtitle: const Text("Notificar 30 días antes del vencimiento"),
              value: _notificationsEnabled,
              onChanged: (bool value) =>
                  setState(() => _notificationsEnabled = value),
              secondary: const Icon(Icons.notifications_active),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _saveDoc,
              child: const Text("Guardar Documento"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime initial = DateTime.now();
    try {
      initial = DateFormat('dd/MM/yyyy').parse(_dateController.text);
    } catch (_) {}

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(
          () => _dateController.text = DateFormat('dd/MM/yyyy').format(picked));
    }
  }
}
