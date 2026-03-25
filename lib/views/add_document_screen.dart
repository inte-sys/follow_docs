// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
// import 'package:uuid/uuid.dart';
// import '../services/database_helper.dart';
// import '../services/notification_service.dart';
// import '../services/ocr_service.dart';
// import 'camera_scanner_screen.dart';

// class AddDocumentScreen extends StatefulWidget {
//   final Map<String, dynamic>? existingDoc;
//   final String? parentId;

//   const AddDocumentScreen({super.key, this.existingDoc, this.parentId});

//   @override
//   State<AddDocumentScreen> createState() => _AddDocumentScreenState();
// }

// class _AddDocumentScreenState extends State<AddDocumentScreen> {
//   final TextEditingController _nameController = TextEditingController();
//   final TextEditingController _dateController = TextEditingController();
//   final TextEditingController _customTypeController = TextEditingController();

//   // Controlador para que el usuario escriba el número de la alerta
//   final TextEditingController _notifValueController =
//       TextEditingController(text: '7');

//   String _selectedType = 'Pasaporte';
//   bool _notificationsEnabled = true;
//   String _notifUnit = 'Días';

//   final List<String> _unitOptions = ['Días', 'Semanas', 'Meses'];
//   final List<String> _docTypes = [
//     'Pasaporte',
//     'Licencia',
//     'Visa',
//     'Seguro',
//     'Otro'
//   ];

//   final dateMaskFormatter = MaskTextInputFormatter(
//     mask: '##/##/####',
//     filter: {"#": RegExp(r'[0-9]')},
//   );

//   @override
//   void initState() {
//     super.initState();
//     if (widget.existingDoc != null) {
//       _nameController.text = widget.existingDoc!['name'] ?? '';
//       _dateController.text = widget.existingDoc!['expiration_date'] ?? '';

//       // RECUPERACIÓN: Cargamos los valores guardados de la antelación
//       _notifValueController.text =
//           (widget.existingDoc!['notif_value'] ?? 7).toString();
//       _notifUnit = widget.existingDoc!['notif_unit'] ?? 'Días';

//       final savedType = widget.existingDoc!['doc_type'] ?? 'Pasaporte';
//       if (_docTypes.contains(savedType)) {
//         _selectedType = savedType;
//       } else {
//         _selectedType = 'Otro';
//         _customTypeController.text = savedType;
//       }
//       _notificationsEnabled = widget.existingDoc!['is_active'] == 1;
//     }
//   }

//   Future<void> _saveDoc() async {
//     if (_nameController.text.isEmpty || _dateController.text.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Rellena nombre y fecha")),
//       );
//       return;
//     }

//     DateTime expiryDate;
//     try {
//       expiryDate = DateFormat('dd/MM/yyyy').parse(_dateController.text);
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Fecha inválida")),
//       );
//       return;
//     }

//     // Leemos los valores de notificación siempre, para que la DB no reciba nulos
//     int notifValue = int.tryParse(_notifValueController.text) ?? 7;
//     int daysToSubtract = _notifUnit == 'Semanas'
//         ? notifValue * 7
//         : (_notifUnit == 'Meses' ? notifValue * 30 : notifValue);

//     final String docId = widget.existingDoc != null
//         ? widget.existingDoc!['id']
//         : const Uuid().v4();
//     final String finalType = _selectedType == 'Otro'
//         ? _customTypeController.text.trim()
//         : _selectedType;

//     final Map<String, dynamic> data = {
//       'id': docId,
//       'name': _nameController.text,
//       'type': 'document',
//       'doc_type': finalType.isEmpty ? 'Otro' : finalType,
//       'expiration_date': _dateController.text,
//       'is_active': _notificationsEnabled ? 1 : 0,
//       'parent_id': widget.parentId,
//       'notif_value': notifValue,
//       'notif_unit': _notifUnit,
//     };

//     try {
//       // 1. Guardamos en la Base de Datos SIEMPRE
//       if (widget.existingDoc != null) {
//         await DatabaseHelper.instance.updateItem(data);
//       } else {
//         await DatabaseHelper.instance.insertItem(data);
//       }

//       // 2. Gestión de Alertas (Independiente del guardado)
//       if (_notificationsEnabled) {
//         final alarmDate = expiryDate.subtract(Duration(days: daysToSubtract));
//         // Solo programamos si es una fecha futura
//         if (alarmDate.isAfter(DateTime.now())) {
//           await NotificationService().scheduleNotification(
//             id: docId.hashCode,
//             title: "Vencimiento Próximo",
//             body:
//                 "Tu ${finalType.toLowerCase()} '${_nameController.text}' vence pronto.",
//             scheduledDate: alarmDate,
//           );
//         }
//       } else {
//         // SOLUCIÓN: Usamos un try-catch interno para que si falla la cancelación, NO rompa el guardado
//         try {
//           await NotificationService().cancelNotification(docId);
//         } catch (e) {
//           debugPrint("No había notificación previa para cancelar.");
//         }
//       }

//       // 3. Si llegamos aquí, el guardado en DB fue exitoso, cerramos la pantalla
//       if (mounted) Navigator.pop(context, true);
//     } catch (e) {
//       debugPrint("ERROR REAL EN DB: $e");
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Error al guardar en base de datos: $e")),
//         );
//       }
//     }
//   }

//   Future<void> _pickAndScanImage() async {
//     final String? imagePath = await Navigator.push(
//       context,
//       MaterialPageRoute(builder: (_) => const CameraScannerScreen()),
//     );

//     if (imagePath != null) {
//       final ocr = OCRService();
//       final result = await ocr.analyzeDocument(imagePath);
//       ocr.dispose();

//       setState(() {
//         if (result['date'] != null) _dateController.text = result['date']!;
//         if (result['type'] != null && _docTypes.contains(result['type'])) {
//           _selectedType = result['type']!;
//         }
//       });
//     }
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _dateController.dispose();
//     _customTypeController.dispose();
//     _notifValueController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(widget.existingDoc == null
//             ? 'Nuevo Documento'
//             : 'Editar Documento'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.check),
//             onPressed: _saveDoc,
//           )
//         ],
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             TextField(
//               controller: _nameController,
//               decoration: const InputDecoration(
//                 labelText: 'Nombre del documento',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 16),
//             DropdownButtonFormField<String>(
//               value: _selectedType,
//               items: _docTypes
//                   .map((t) => DropdownMenuItem(value: t, child: Text(t)))
//                   .toList(),
//               onChanged: (val) => setState(() => _selectedType = val!),
//               decoration: const InputDecoration(
//                   labelText: 'Categoría', border: OutlineInputBorder()),
//             ),
//             if (_selectedType == 'Otro') ...[
//               const SizedBox(height: 16),
//               TextField(
//                 controller: _customTypeController,
//                 decoration: const InputDecoration(
//                     labelText: 'Tipo personalizado',
//                     border: OutlineInputBorder()),
//               ),
//             ],
//             const SizedBox(height: 16),
//             TextFormField(
//               controller: _dateController,
//               inputFormatters: [dateMaskFormatter],
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(
//                 labelText: 'Fecha de Vencimiento (DD/MM/AAAA)',
//                 border: const OutlineInputBorder(),
//                 suffixIcon: IconButton(
//                   icon: const Icon(Icons.camera_alt),
//                   onPressed: _pickAndScanImage,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 16),
//             SwitchListTile(
//               title: const Text("Notificaciones automáticas"),
//               subtitle: const Text("Programar aviso de vencimiento"),
//               value: _notificationsEnabled,
//               onChanged: (val) => setState(() => _notificationsEnabled = val),
//             ),
//             if (_notificationsEnabled)
//               Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Wrap(
//                   crossAxisAlignment: WrapCrossAlignment.center,
//                   spacing: 8.0,
//                   children: [
//                     const Text("Avisar "),
//                     // Cuadro de texto para escribir el número
//                     SizedBox(
//                       width: 50,
//                       child: TextField(
//                         controller: _notifValueController,
//                         keyboardType: TextInputType.number,
//                         textAlign: TextAlign.center,
//                         decoration: const InputDecoration(
//                           hintText: '0',
//                         ),
//                       ),
//                     ),
//                     DropdownButton<String>(
//                       value: _notifUnit,
//                       items: _unitOptions
//                           .map(
//                               (u) => DropdownMenuItem(value: u, child: Text(u)))
//                           .toList(),
//                       onChanged: (val) => setState(() => _notifUnit = val!),
//                     ),
//                     const Text(" antes."),
//                   ],
//                 ),
//               ),
//             const SizedBox(height: 32),
//             SizedBox(
//               width: double.infinity,
//               height: 52,
//               child: ElevatedButton.icon(
//                 onPressed: _saveDoc,
//                 icon: const Icon(Icons.save),
//                 label: const Text("GUARDAR DATOS"),
//               ),
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }

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

  // Controlador para la cantidad de antelación
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

      // Recuperar configuración de notificación
      int savedValue = widget.existingDoc!['notif_value'] ?? 0;
      _notifUnit = widget.existingDoc!['notif_unit'] ?? 'Días';

      // Si el valor es 0, las notificaciones están apagadas visualmente
      if (savedValue > 0) {
        _notifValueController.text = savedValue.toString();
        _notificationsEnabled = true;
      } else {
        _notifValueController.text =
            '7'; // Valor por defecto para cuando se encienda
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

  /// Método de guardado con lógica de notificaciones y persistencia
  Future<void> _saveDoc() async {
    if (_nameController.text.isEmpty || _dateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Rellena nombre y fecha")),
      );
      return;
    }

    DateTime expiryDate;
    try {
      expiryDate = DateFormat('dd/MM/yyyy').parse(_dateController.text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fecha inválida")),
      );
      return;
    }

    // Lógica: Si el switch está apagado, el valor en DB será 0
    int finalNotifValue = _notificationsEnabled
        ? (int.tryParse(_notifValueController.text) ?? 7)
        : 0;

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
      'name': _nameController.text,
      'type': 'document',
      'doc_type': finalType.isEmpty ? 'Otro' : finalType,
      'expiration_date': _dateController.text,
      'is_active':
          1, // isActive: 1 significa que el usuario puede manipular el item
      'parent_id': widget.parentId,
      'notif_value': finalNotifValue, // 0 significa notificaciones apagadas
      'notif_unit': _notifUnit,
    };

    try {
      // 1. Guardamos en la Base de Datos
      if (widget.existingDoc != null) {
        await DatabaseHelper.instance.updateItem(data);
      } else {
        await DatabaseHelper.instance.insertItem(data);
      }

      // 2. Gestión de Alertas (Independiente del guardado principal)
      try {
        if (finalNotifValue > 0) {
          final alarmDate = expiryDate.subtract(Duration(days: daysToSubtract));
          // Solo programamos si es una fecha futura
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
          // Si el valor es 0 o se apagó, intentamos cancelar cualquier alerta previa
          await NotificationService().cancelNotification(docId);
        }
      } catch (notifError) {
        debugPrint("Error no crítico en notificación: $notifError");
      }

      // 3. Salida de la pantalla si el guardado en DB fue exitoso
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("ERROR REAL EN DB: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al guardar en base de datos: $e")),
        );
      }
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
                  labelText: 'Categoría', border: OutlineInputBorder()),
            ),
            if (_selectedType == 'Otro') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _customTypeController,
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
                  onPressed: _pickAndScanImage,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text("Notificaciones automáticas"),
              subtitle: const Text("Programar aviso de vencimiento"),
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
                      width: 50,
                      child: TextField(
                        controller: _notifValueController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(hintText: '0'),
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
