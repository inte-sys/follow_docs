import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../models/item_model.dart';
import 'add_document_screen.dart';
import 'package:uuid/uuid.dart';

enum DocFilter { all, upcoming, expired }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  // Permite que el servicio de notificaciones active la búsqueda desde fuera
  static void searchFromNotification(String itemName) {
    _homeState?.activateFilterByName(itemName);
  }

  static _HomeScreenState? _homeState;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<FollowItem> _items = [];
  List<Map<String, dynamic>> _rawItems = [];
  // Variables de estado para Configuración (ya no son valores hardcode) [cite: 121]
  int _defaultNotifValue = 7;
  String _defaultNotifUnit = 'Días';
  bool _globalNotificationsEnabled = true;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 8, minute: 0);
  String _selectedLanguage = 'Español';
  String _dateFormat = 'dd/MM/yyyy';

  final List<Map<String, String?>> _navigationStack = [
    {'id': null, 'name': 'Principal'}
  ];

  final _searchController = TextEditingController();
  bool _isSearching = false;
  DocFilter _activeFilter = DocFilter.all;

  @override
  void initState() {
    super.initState();
    HomeScreen._homeState = this;
    _refreshItems();
  }

  @override
  void dispose() {
    if (HomeScreen._homeState == this) HomeScreen._homeState = null;
    _searchController.dispose();
    super.dispose();
  }

  // Método para activar la búsqueda de un elemento específico
  void activateFilterByName(String name) {
    setState(() {
      _isSearching = true;
      _searchController.text = name;
      _activeFilter = DocFilter.all; // Reseteamos filtros para que aparezca
    });
    _refreshItems();
  }

  Map<String, String?> get _currentLevel => _navigationStack.last;

  Future<void> _refreshItems() async {
    final searchText = _searchController.text.trim();
    final List<Map<String, dynamic>> data =
        await DatabaseHelper.instance.getItems(
      parentId: _currentLevel['id'],
      search: searchText.isEmpty ? null : searchText,
    );

    setState(() {
      _rawItems = data;
      _items = data.map((item) => FollowItem.fromMap(item)).toList();

      if (_activeFilter == DocFilter.expired) {
        _items = _items
            .where((i) => i.type == ItemType.document && i.isExpired)
            .toList();
      } else if (_activeFilter == DocFilter.upcoming) {
        final now = DateTime.now();
        final nextWeek = now.add(const Duration(days: 7));
        _items = _items.where((i) {
          if (i.type != ItemType.document || i.expirationDate == null) {
            return false;
          }
          return i.expirationDate!.isAfter(now) &&
              i.expirationDate!.isBefore(nextWeek);
        }).toList();
      }
    });
  }

  void _goBack() {
    if (_navigationStack.length > 1) {
      setState(() {
        _navigationStack.removeLast();
        _activeFilter = DocFilter.all;
      });
      _refreshItems();
    }
  }

  void _showItemDetails(FollowItem item, Map<String, dynamic> rawDoc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${rawDoc['doc_type'] ?? 'Documento'}",
                  style: TextStyle(
                      color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Text(
              item.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (item.expirationDate != null) ...[
              const Text("Vencimiento:",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey)),
              Text(
                "${DateFormat('dd/MM/yyyy').format(item.expirationDate!)} (${item.expirationHint})",
                style: TextStyle(
                    fontSize: 18,
                    color: item.isExpired ? Colors.red : Colors.black),
              ),
              const SizedBox(height: 12),
            ],
            const Text("Notificación programada:",
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            Text(
              item.notifValue > 0
                  ? "${item.notifValue} ${item.notifUnit} antes"
                  : "Desactivada",
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _editItem(item, rawDoc);
                },
                icon: const Icon(Icons.edit),
                label: const Text("EDITAR"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editItem(FollowItem item, Map<String, dynamic> rawDoc) async {
    if (item.type == ItemType.folder) {
      _showFolderDialog(existingFolder: rawDoc);
    } else {
      final res = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddDocumentScreen(
            existingDoc: rawDoc,
            parentId: rawDoc['parent_id'],
          ),
        ),
      );
      if (res == true) _refreshItems();
    }
  }

  Widget _buildItemRow(FollowItem item) {
    final Map<String, dynamic> rawDoc = _rawItems.firstWhere(
      (element) => element['id'] == item.id,
      orElse: () => {},
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Dismissible(
        key: Key(item.id),
        // Cambiamos a endToStart (deslizar a la izquierda) para evitar
        // conflicto con el gesto de "Atrás" de Android desde el borde derecho.
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          // Re-insertamos la pregunta de seguridad que protege contra borrados accidentales
          return await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text("Confirmar eliminación"),
                content: Text("¿Deseas borrar '${item.name}'?"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text("CANCELAR"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text("ELIMINAR",
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              );
            },
          );
        },
        onDismissed: (_) async {
          await DatabaseHelper.instance.deleteItem(item.id);
          _refreshItems();
        },
        background: Container(
          decoration: BoxDecoration(
              color: Colors.red, borderRadius: BorderRadius.circular(12)),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        child: Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: item.type == ItemType.folder
                  ? Colors.amber.shade100
                  : (item.isExpired
                      ? Colors.red.shade100
                      : Colors.blue.shade100),
              child: Icon(
                item.type == ItemType.folder ? Icons.folder : Icons.description,
                color: item.type == ItemType.folder
                    ? Colors.amber.shade800
                    : (item.isExpired
                        ? Colors.red.shade800
                        : Colors.blue.shade800),
              ),
            ),
            title: Text(item.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: item.type == ItemType.document &&
                    item.expirationDate != null
                ? Text(
                    "Vence: ${DateFormat('dd/MM/yyyy').format(item.expirationDate!)} (${item.expirationHint})",
                    style: TextStyle(
                        color:
                            item.isExpired ? Colors.red : Colors.grey.shade600))
                : FutureBuilder<List<Map<String, dynamic>>>(
                    future: DatabaseHelper.instance.getItems(parentId: item.id),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Text("Sin documentos");
                      }
                      final count = snapshot.data!.length;
                      return Text("$count documento${count > 1 ? 's' : ''}");
                    },
                  ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.type == ItemType.document)
                  IconButton(
                    icon: Icon(
                      item.notifValue > 0
                          ? Icons.notifications_active
                          : Icons.notifications_off,
                      color: item.notifValue > 0 ? Colors.blue : Colors.grey,
                    ),
                    onPressed: () async {
                      if (item.notifValue > 0 && item.expirationDate != null) {
                        int days = item.notifValue;
                        if (item.notifUnit == 'Semanas') days *= 7;
                        if (item.notifUnit == 'Meses') days *= 30;

                        final reminderDate =
                            item.expirationDate!.subtract(Duration(days: days));
                        final dateStr = DateFormat('dd/MM/yyyy')
                            .format(item.expirationDate!);
                        final reminderStr =
                            DateFormat('dd/MM/yyyy').format(reminderDate);

                        await NotificationService().showInstantNotification(
                          title:
                              "${rawDoc['doc_type'] ?? 'Documento'}: ${item.name}",
                          body:
                              "Renovar ${item.name} antes del $dateStr. Te lo recordaré el $reminderStr.",
                          payload: item.name,
                        );
                      }
                    },
                  ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
            onTap: () {
              if (item.type == ItemType.folder) {
                setState(() {
                  _navigationStack.add({'id': item.id, 'name': item.name});
                  _activeFilter = DocFilter.all;
                });
                _refreshItems();
              } else {
                _showItemDetails(item, rawDoc);
              }
            },
          ),
        ),
      ),
    );
  }

  void _showFolderDialog({Map<String, dynamic>? existingFolder}) {
    final TextEditingController folderController = TextEditingController(
        text: existingFolder != null ? existingFolder['name'] : '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(existingFolder == null ? "Nueva Carpeta" : "Editar Carpeta"),
        content: TextField(
          controller: folderController,
          maxLength: 32,
          decoration: const InputDecoration(
              labelText: "Nombre de la carpeta", counterText: ""),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (folderController.text.trim().isNotEmpty) {
                final data = {
                  'id': existingFolder?['id'] ?? const Uuid().v4(),
                  'name': folderController.text.trim(),
                  'type': 'folder',
                  'is_active': 1,
                  'parent_id': _currentLevel['id'],
                };
                if (existingFolder == null) {
                  await DatabaseHelper.instance.insertItem(data);
                } else {
                  await DatabaseHelper.instance.updateItem(data);
                }
                // ignore: use_build_context_synchronously
                if (mounted) Navigator.pop(context);
                _refreshItems();
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  void _showCreateOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.create_new_folder),
            title: const Text("Crear Carpeta"),
            onTap: () {
              Navigator.pop(context);
              _showFolderDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text("Crear Documento"),
            onTap: () async {
              Navigator.pop(context);
              final res = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          AddDocumentScreen(parentId: _currentLevel['id'])));
              if (res == true) _refreshItems();
            },
          ),
        ],
      ),
    );
  }

// Implementación del Panel de Configuración [cite: 121]
  void _showConfigPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setPanelState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Título con Chevrón para regresar [cite: 121]
              AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text("Configuración"),
                backgroundColor: Colors.transparent,
                elevation: 0,
                foregroundColor: Colors.black,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Subtítulo: Recordatorio [cite: 121]
                    const Text("Recordatorio",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    ListTile(
                      title: const Text("Cantidad de días por defecto"),
                      trailing: SizedBox(
                        width: 50,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          onChanged: (val) {
                            _defaultNotifValue = int.tryParse(val) ?? 7;
                          },
                          controller: TextEditingController(
                              text: _defaultNotifValue.toString()),
                        ),
                      ),
                    ),
                    ListTile(
                      title: const Text("Tipo de lapso"),
                      trailing: DropdownButton<String>(
                        value: _defaultNotifUnit,
                        items: ['Días', 'Semanas', 'Meses']
                            .map((u) =>
                                DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (val) {
                          setPanelState(() => _defaultNotifUnit = val!);
                        },
                      ),
                    ),
                    const Divider(),

                    // Subtítulo: Notificaciones [cite: 121]
                    const Text("Notificaciones",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    SwitchListTile(
                      secondary: Icon(_globalNotificationsEnabled
                          ? Icons.notifications_active
                          : Icons.notifications_off),
                      title: const Text("Activar notificaciones"),
                      value: _globalNotificationsEnabled,
                      onChanged: (val) {
                        setPanelState(() => _globalNotificationsEnabled = val);
                      },
                    ),
                    ListTile(
                      title: const Text("Probar notificaciones"),
                      trailing: ElevatedButton(
                        onPressed: _globalNotificationsEnabled
                            ? () {
                                Future.delayed(
                                    const Duration(milliseconds: 500), () {
                                  NotificationService().showInstantNotification(
                                    title: "Prueba de Sistema",
                                    body:
                                        "Las notificaciones están configuradas correctamente.",
                                  );
                                });
                              }
                            : null, // Deshabilitado si están inactivas [cite: 121]
                        child: const Text("Probar"),
                      ),
                    ),
                    ListTile(
                      title: const Text("Hora de presentación"),
                      trailing: TextButton(
                        child: Text(_notificationTime.format(context)),
                        onPressed: () async {
                          final picked = await showTimePicker(
                              context: context, initialTime: _notificationTime);
                          if (picked != null) {
                            setPanelState(() => _notificationTime = picked);
                          }
                        },
                      ),
                    ),
                    const Divider(),

                    // Subtítulo: Respaldos [cite: 121]
                    const Text("Respaldos",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Row(
                      children: [
                        Expanded(
                            child: ElevatedButton(
                                onPressed: () {},
                                child: const Text("Hacer respaldo"))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: OutlinedButton(
                                onPressed: () {},
                                child: const Text("Recuperar"))),
                      ],
                    ),
                    const Divider(),

                    // Subtítulo: Configuración regional [cite: 121]
                    const Text("Configuración regional",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    ListTile(
                      title: const Text("Idioma"),
                      trailing: DropdownButton<String>(
                        value: _selectedLanguage,
                        items: ['Español', 'Inglés']
                            .map((l) =>
                                DropdownMenuItem(value: l, child: Text(l)))
                            .toList(),
                        onChanged: (val) =>
                            setPanelState(() => _selectedLanguage = val!),
                      ),
                    ),
                    Text("Zona horaria: ${DateTime.now().timeZoneName}"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutPanel() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.description, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            const Text("Follow Docs",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text("Versión 1.0.0", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            const Text(
              "Aplicación diseñada para la gestión y seguimiento de documentos con vencimiento.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Text("Desarrollado por: Intesys LLC, 2026",
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FilterChip(
              label: const Text("Todos"),
              selected: _activeFilter == DocFilter.all,
              onSelected: (_) {
                setState(() => _activeFilter = DocFilter.all);
                _refreshItems();
              }),
          FilterChip(
              label: const Text("Próximos"),
              selected: _activeFilter == DocFilter.upcoming,
              onSelected: (_) {
                setState(() => _activeFilter = DocFilter.upcoming);
                _refreshItems();
              }),
          FilterChip(
              label: const Text("Vencidos"),
              selected: _activeFilter == DocFilter.expired,
              onSelected: (_) {
                setState(() => _activeFilter = DocFilter.expired);
                _refreshItems();
              }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _navigationStack.length <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  maxLength: 64,
                  decoration: const InputDecoration(
                      hintText: "Buscar...",
                      border: InputBorder.none,
                      counterText: ""),
                  onChanged: (_) => _refreshItems(),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Follow Docs", style: TextStyle(fontSize: 12)),
                    Text(_currentLevel['name']!,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () => setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
                _refreshItems();
              }),
            ),
          ],
        ),
        body: Column(
          children: [
            if (!_isSearching) _buildFilterChips(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshItems,
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: _items.length,
                  itemBuilder: (context, index) => _buildItemRow(_items[index]),
                ),
              ),
            ),
          ],
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.blue),
                child: Text('Menú Principal',
                    style: TextStyle(color: Colors.white, fontSize: 24)),
              ),
              ListTile(
                leading: const Icon(Icons.create_new_folder),
                title: const Text('Carpeta'),
                onTap: () {
                  Navigator.pop(context); // Cierra el drawer
                  _showFolderDialog(); // Reutiliza la acción existente [cite: 122]
                },
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Documento'),
                onTap: () async {
                  Navigator.pop(context);
                  final res = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            AddDocumentScreen(parentId: _currentLevel['id'])),
                  );
                  if (res == true)
                    _refreshItems(); // Reutiliza la acción existente [cite: 122]
                },
              ),
              const Divider(), // Espacio de separación [cite: 121]
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Configuración'),
                onTap: () {
                  Navigator.pop(context);
                  _showConfigPanel(); // Nuevo panel
                },
              ),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('Acerca de'),
                onTap: () {
                  Navigator.pop(context);
                  _showAboutPanel(); // Nuevo panel
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
