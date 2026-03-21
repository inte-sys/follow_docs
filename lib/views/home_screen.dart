import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../models/item_model.dart';
import 'add_document_screen.dart';
import 'package:uuid/uuid.dart';
// import 'package:flutter/services.dart';

enum DocFilter { all, upcoming, expired }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<FollowItem> _items = [];
  List<Map<String, dynamic>> _rawItems = [];

  // Pila de navegación para gestionar niveles de carpetas y títulos
  final List<Map<String, String?>> _navigationStack = [
    {'id': null, 'name': 'Principal'}
  ];

  final _searchController = TextEditingController();
  bool _isSearching = false;
  DocFilter _activeFilter = DocFilter.all;

  @override
  void initState() {
    super.initState();
    _refreshItems();
  }

  // Getter para obtener el nivel actual de la pila
  Map<String, String?> get _currentLevel => _navigationStack.last;

  Future<void> _refreshItems() async {
    // Consulta basada en el ID del nivel actual de la pila
    // final data =
    //     await DatabaseHelper.instance.queryItemsByParent(_currentLevel['id']);
    // Si hay un filtro activo que no sea "todos", buscamos en toda la DB
    List<Map<String, dynamic>> data;
    if (_activeFilter == DocFilter.all) {
      data =
          await DatabaseHelper.instance.queryItemsByParent(_currentLevel['id']);
    } else {
      data = await DatabaseHelper.instance.queryAllItems();
    }

    setState(() {
      _rawItems = data;
      _items = data.map((item) {
        DateTime? expiry;
        if (item['expiration_date'] != null &&
            item['expiration_date'].toString().isNotEmpty) {
          try {
            expiry = DateFormat('dd/MM/yyyy')
                .parse(item['expiration_date'].toString());
          } catch (_) {}
        }

        return FollowItem(
          id: item['id']?.toString() ?? '',
          name: item['name']?.toString() ?? 'Sin nombre',
          type: item['type'] == 'folder' ? ItemType.folder : ItemType.document,
          expirationDate: expiry,
        );
      }).toList();

      // Aplicar lógica de filtrado por fecha
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
        _activeFilter = DocFilter.all; // Resetear filtro al navegar
      });
      _refreshItems();
    }
  }

  Widget _buildFilterChips() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          FilterChip(
            label: const Text("Todos"),
            selected: _activeFilter == DocFilter.all,
            onSelected: (val) {
              setState(() => _activeFilter = DocFilter.all);
              _refreshItems();
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text("Próximos (7d)"),
            selected: _activeFilter == DocFilter.upcoming,
            onSelected: (val) {
              setState(() => _activeFilter = DocFilter.upcoming);
              _refreshItems();
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text("Vencidos"),
            selected: _activeFilter == DocFilter.expired,
            selectedColor: Colors.red.shade100,
            onSelected: (val) {
              setState(() => _activeFilter = DocFilter.expired);
              _refreshItems();
            },
          ),
        ],
      ),
    );
  }

  // Future<void> _searchDocuments(String query) async {
  //   if (query.isEmpty) {
  //     _refreshItems();
  //     return;
  //   }

  //   // Consulta global para la búsqueda
  //   final allData = await DatabaseHelper.instance.queryAllItems();

  //   setState(() {
  //     // IMPORTANTE: Actualizamos _rawItems con los resultados de la búsqueda
  //     // para que _buildItemRow encuentre el documento original al editar.
  //     _rawItems = allData
  //         .where((item) =>
  //             item['type'] == 'document' &&
  //             item['name']
  //                 .toString()
  //                 .toLowerCase()
  //                 .contains(query.toLowerCase()))
  //         .toList();

  //     _items = _rawItems.map((item) {
  //       DateTime? expiry;
  //       if (item['expiration_date'] != null) {
  //         try {
  //           expiry = DateFormat('dd/MM/yyyy')
  //               .parse(item['expiration_date'].toString());
  //         } catch (_) {}
  //       }
  //       return FollowItem(
  //         id: item['id'].toString(),
  //         name: item['name'].toString(),
  //         type: ItemType.document,
  //         expirationDate: expiry,
  //       );
  //     }).toList();
  //   });
  // }

  Widget _buildItemRow(FollowItem item) {
    final Map<String, dynamic> rawDoc = _rawItems.firstWhere(
      (element) => element['id'] == item.id,
      orElse: () => {},
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Dismissible(
        key: Key(item.id),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(12)),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete_sweep, color: Colors.white, size: 28),
        ),
        onDismissed: (_) async {
          await DatabaseHelper.instance.deleteItem(item.id);
          _refreshItems();
        },
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
            subtitle: item.expirationDate != null
                ? Text(
                    "Vence: ${DateFormat('dd/MM/yyyy').format(item.expirationDate!)}",
                    style: TextStyle(
                        color:
                            item.isExpired ? Colors.red : Colors.grey.shade600))
                : const Text("Carpeta"),
            trailing: IconButton(
              icon: const Icon(Icons.edit_note),
              onPressed: () async {
                final res = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddDocumentScreen(
                      existingDoc: rawDoc,
                      parentId: _isSearching || _activeFilter != DocFilter.all
                          ? rawDoc['parent_id']
                          : _currentLevel['id'],
                    ),
                  ),
                );
                if (res == true) _refreshItems();
              },
            ),
            onTap: () {
              if (item.type == ItemType.folder) {
                setState(() {
                  _navigationStack.add({'id': item.id, 'name': item.name});
                  _activeFilter = DocFilter.all;
                });
                _refreshItems();
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
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (folderController.text.trim().isNotEmpty) {
                if (existingFolder == null) {
                  await DatabaseHelper.instance.insertItem({
                    'id': const Uuid().v4(),
                    'name': folderController.text.trim(),
                    'type': 'folder',
                    'is_active': 1,
                    'parent_id': _currentLevel['id'],
                  });
                } else {
                  await DatabaseHelper.instance.updateItem({
                    'id': existingFolder['id'],
                    'name': folderController.text.trim(),
                    'type': 'folder',
                    'is_active': 1,
                  });
                }
                if (!context.mounted) return;
                Navigator.pop(context);
                _refreshItems();
              }
            },
            child: Text(existingFolder == null ? "Crear" : "Guardar"),
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
            title: const Text("Crear Elemento"),
            onTap: () async {
              Navigator.pop(context);
              final res = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AddDocumentScreen(
                            parentId: _currentLevel['id'],
                          )));
              if (res == true) _refreshItems();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _navigationStack.length <= 1,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      hintText: "Buscar...",
                      hintStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none),
                  onChanged: (q) =>
                      _refreshItems(), // Simplificado para usar la misma lógica
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
              onPressed: () => setState(() => _isSearching = !_isSearching),
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
                  itemCount: _items.length,
                  itemBuilder: (context, index) => _buildItemRow(_items[index]),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCreateOptions(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
