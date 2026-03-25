import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
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
  DateTime? _calculatedDate;
  bool _isPastDocDate = false;
  bool _showFlash = false;
  Timer? _correctionTimer;

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
    _initData();
    _dateController.addListener(_updateCalculations);
    _notifValueController.addListener(_updateCalculations);
  }

  void _initData() {
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
      _updateCalculations();
    }
  }

  void _updateCalculations() {
    if (_dateController.text.length < 10) {
      return;
    }

    DateTime? expiryDate;
    try {
      expiryDate = DateFormat('dd/MM/yyyy').parse(_dateController.text);
    } catch (_) {
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      _isPastDocDate = expiryDate!.isBefore(today);
      if (_isPastDocDate) {
        _notificationsEnabled = false;
      }
    });

    if (_isPastDocDate) {
      return;
    }

    int val = int.tryParse(_notifValueController.text) ?? 0;
    Duration offset = _getDuration(val, _notifUnit);
    DateTime reminder = expiryDate.subtract(offset);

    setState(() {
      _calculatedDate = reminder;
    });

    if (reminder.isBefore(today)) {
      _triggerCorrection(expiryDate, today);
    } else {
      _correctionTimer?.cancel();
      setState(() {
        _showFlash = false;
      });
    }
  }

  Duration _getDuration(int val, String unit) {
    if (unit == 'Semanas') {
      return Duration(days: val * 7);
    }
    if (unit == 'Meses') {
      return Duration(days: val * 30);
    }
    return Duration(days: val);
  }

  void _triggerCorrection(DateTime expiry, DateTime today) {
    _correctionTimer?.cancel();
    setState(() {
      _showFlash = true;
    });

    _correctionTimer = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) {
        return;
      }

      final diffDays = expiry.difference(today).inDays;

      setState(() {
        _showFlash = false;

        if (diffDays >= 30) {
          _notifUnit = 'Meses';
          _notifValueController.text = (diffDays / 30).floor().toString();
        } else if (diffDays >= 7) {
          _notifUnit = 'Semanas';
          _notifValueController.text = (diffDays / 7).floor().toString();
        } else {
          _notifUnit = 'Días';
          _notifValueController.text = diffDays.toString();
        }
      });
      _updateCalculations();
    });
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

    final maxYear = DateTime.now().year + 20;
    if (expiryDate.year > maxYear) {
      _showError("La fecha no puede exceder los 20 años (Año $maxYear)");
      return;
    }

    int finalNotifValue = _notificationsEnabled
        ? (int.tryParse(_notifValueController.text) ?? 0)
        : 0;

    final Map<String, dynamic> data = {
      'id': widget.existingDoc != null
          ? widget.existingDoc!['id']
          : const Uuid().v4(),
      'name': _nameController.text.trim(),
      'type': 'document',
      'doc_type': _selectedType == 'Otro'
          ? _customTypeController.text.trim()
          : _selectedType,
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

      if (finalNotifValue > 0 && _calculatedDate != null) {
        await NotificationService().scheduleNotification(
          id: data['id'].hashCode,
          title: "${data['doc_type']}: ${data['name']}",
          body:
              "Renovar ${data['name']} antes del ${_dateController.text}. Te lo recordaré el ${DateFormat('dd/MM/yyyy').format(_calculatedDate!)}.",
          scheduledDate: _calculatedDate!,
        );
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError("Error al guardar");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickAndScanImage() async {
    final String? imagePath = await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const CameraScannerScreen()));
    if (imagePath != null) {
      final result = await OCRService().analyzeDocument(imagePath);
      setState(() {
        if (result['date'] != null) {
          _dateController.text = result['date']!;
        }
        if (result['type'] != null && _docTypes.contains(result['type'])) {
          _selectedType = result['type']!;
        }
      });
      _updateCalculations();
    }
  }

  @override
  void dispose() {
    _correctionTimer?.cancel();
    _nameController.dispose();
    _dateController.dispose();
    _customTypeController.dispose();
    _notifValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todayStr = DateFormat('dd/MM/yyyy').format(DateTime.now());

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
              maxLength: 64,
              decoration: const InputDecoration(
                  labelText: 'Nombre del documento',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              items: _docTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedType = val!;
                });
              },
              decoration: const InputDecoration(
                  labelText: 'Categoría', border: OutlineInputBorder()),
            ),
            if (_selectedType == 'Otro') ...{
              const SizedBox(height: 16),
              TextField(
                controller: _customTypeController,
                maxLength: 20,
                decoration: const InputDecoration(
                    labelText: 'Tipo personalizado',
                    border: OutlineInputBorder()),
              ),
            },
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
            Opacity(
              opacity: _isPastDocDate ? 0.5 : 1.0,
              child: IgnorePointer(
                ignoring: _isPastDocDate,
                child: SwitchListTile(
                  title: const Text("Notificaciones automáticas"),
                  value: _notificationsEnabled,
                  onChanged: (val) {
                    setState(() {
                      _notificationsEnabled = val;
                    });
                  },
                ),
              ),
            ),
            if (_notificationsEnabled && !_isPastDocDate) ...{
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
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
                              LengthLimitingTextInputFormatter(3)
                            ],
                          ),
                        ),
                        DropdownButton<String>(
                          value: _notifUnit,
                          items: _unitOptions
                              .map((u) =>
                                  DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              _notifUnit = val!;
                            });
                            _updateCalculations();
                          },
                        ),
                        const Text(" antes."),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_calculatedDate != null) ...{
                      Row(
                        children: [
                          const Text("Recordar el: ",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          if (_showFlash) ...[
                            Text(
                              DateFormat('dd/MM/yyyy').format(_calculatedDate!),
                              style: const TextStyle(
                                color: Colors.red,
                                decoration: TextDecoration.lineThrough,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                size: 16, color: Colors.grey),
                            Text(
                              todayStr,
                              style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold),
                            ),
                          ] else ...{
                            Text(DateFormat('dd/MM/yyyy')
                                .format(_calculatedDate!)),
                          },
                        ],
                      ),
                    },
                  ],
                ),
              ),
            },
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
