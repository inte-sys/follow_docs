import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../models/item_model.dart';
import 'add_document_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';

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

  @override
  void initState() {
    super.initState();
    _refreshItems();
  }

  // Getter para obtener el nivel actual de la pila
  Map<String, String?> get _currentLevel => _navigationStack.last;

  Future<void> _refreshItems() async {
    // Consulta basada en el ID del nivel actual de la pila
    final data =
        await DatabaseHelper.instance.queryItemsByParent(_currentLevel['id']);

    setState(() {
      _rawItems = data;
      _items = data.map((item) {
        DateTime? expiry;
        if (item['expiration_date'] != null &&
            item['expiration_date'].toString().isNotEmpty) {
          try {
            expiry = DateFormat('dd/MM/yyyy')
                .parse(item['expiration_date'].toString());
          } catch (e) {
            debugPrint("Error fecha: $e");
          }
        }

        return FollowItem(
          id: item['id']?.toString() ?? '',
          name: item['name']?.toString() ?? 'Sin nombre',
          type: item['type'] == 'folder' ? ItemType.folder : ItemType.document,
          expirationDate: expiry,
        );
      }).toList();
    });
  }

  void _goBack() {
    if (_navigationStack.length > 1) {
      setState(() {
        _navigationStack.removeLast();
      });
      _refreshItems();
    }
  }

  Future<void> _searchDocuments(String query) async {
    if (query.isEmpty) {
      _refreshItems();
      return;
    }

    // Búsqueda global de documentos (ignora carpetas para encontrar archivos)
    final data = await DatabaseHelper.instance.queryAllItems();
    setState(() {
      _items = data
          .where((item) =>
              item['type'] == 'document' &&
              item['name']
                  .toString()
                  .toLowerCase()
                  .contains(query.toLowerCase()))
          .map((item) {
        // Reutilización de la lógica de mapeo...
        DateTime? expiry;
        if (item['expiration_date'] != null) {
          try {
            expiry = DateFormat('dd/MM/yyyy').parse(item['expiration_date']);
          } catch (_) {}
        }
        return FollowItem(
          id: item['id'].toString(),
          name: item['name'].toString(),
          type: ItemType.document,
          expirationDate: expiry,
        );
      }).toList();
    });
  }

  Widget _buildItemRow(FollowItem item) {
    final Map<String, dynamic> rawDoc = _rawItems.firstWhere(
      (element) => element['id'] == item.id,
      orElse: () => {},
    );

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Confirmar"),
            content: Text("¿Deseas eliminar '${item.name}'?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancelar"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child:
                    const Text("Eliminar", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        await DatabaseHelper.instance.deleteItem(item.id);
        _refreshItems();
      },
      child: ListTile(
        leading: Icon(
          item.type == ItemType.folder ? Icons.folder : Icons.description,
          color: item.isExpired ? Colors.red : Colors.blue,
        ),
        title: Text(item.name),
        subtitle: item.expirationDate != null
            ? Text(
                "Vence: ${DateFormat('dd/MM/yyyy').format(item.expirationDate!)}")
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () async {
            if (item.type == ItemType.folder) {
              _showFolderDialog(existingFolder: rawDoc);
            } else {
              final res = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddDocumentScreen(
                      existingDoc: rawDoc, parentId: _currentLevel['id']),
                ),
              );
              if (res == true) _refreshItems();
            }
          },
        ),
        onTap: () {
          if (item.type == ItemType.folder) {
            setState(() {
              _navigationStack.add({'id': item.id, 'name': item.name});
            });
            _refreshItems();
          }
        },
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
                if (!mounted) return;
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
                  decoration: const InputDecoration(
                      hintText: "Buscar documento...",
                      border: InputBorder.none),
                  onChanged: _searchDocuments,
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
          leading: !_isSearching && _navigationStack.length > 1
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new),
                  onPressed: _goBack,
                )
              : null,
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _refreshItems();
                  }
                });
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refreshItems,
          child: ListView.builder(
            itemCount: _items.length,
            itemBuilder: (context, index) => _buildItemRow(_items[index]),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showCreateOptions,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
