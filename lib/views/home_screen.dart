import 'package:flutter/material.dart';
import '../widgets/item_tile.dart';
import '../models/item_model.dart';
import 'package:intl/intl.dart'; // Para DateFormat
import '../services/database_helper.dart'; // Para DatabaseHelper
import 'add_document_screen.dart'; // Para AddDocumentScreen
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Estado persistente de las secciones
  bool _isExpiredOpen = true;
  bool _isAllOpen = false;

  List<FollowItem> _items = [];

  @override
  void initState() {
    super.initState();
    _refreshItems();
  }

  Future<void> _refreshItems() async {
    final data = await DatabaseHelper.instance.queryAllItems();
    setState(() {
      // Convertimos los mapas de la DB a objetos de nuestro modelo
      _items = data
          .map((item) => FollowItem(
                id: item['id'],
                name: item['name'],
                type: item['type'] == 'folder'
                    ? ItemType.folder
                    : ItemType.document,
                expirationDate: item['expiration_date'] != null
                    ? DateFormat('dd/MM/yyyy').parse(item['expiration_date'])
                    : null,
              ))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Follow Docs"),
        actions: [
          IconButton(icon: const Icon(Icons.sort), onPressed: () {}),
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        ],
      ),
      body: ListView(
        // stickyHeader: true,
        children: [
          ExpansionPanelList(
            expansionCallback: (index, isExpanded) {
              setState(() {
                if (index == 0) {
                  _isExpiredOpen = !isExpanded;
                } else {
                  _isAllOpen = !isExpanded;
                }
              });
            },
            children: [
              ExpansionPanel(
                headerBuilder: (context, isExp) =>
                    const ListTile(title: Text("Vencidos")),
                body: const Column(
                    children: []), // Aquí irían los ItemTile vencidos
                isExpanded: _isExpiredOpen,
              ),
              ExpansionPanel(
                headerBuilder: (context, isExp) =>
                    const ListTile(title: Text("Todos")),
                body: Column(
                  children: _items.isEmpty
                      ? [
                          const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text("No hay elementos"))
                        ]
                      : _items
                          .map((item) => ItemTile(
                                item: item,
                                onTap: () {
                                  // Lógica para entrar a carpeta o ver detalle
                                },
                              ))
                          .toList(),
                ),
                isExpanded: _isAllOpen,
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateOptions,
        child: const Icon(Icons.add),
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
              // Aquí deberías llamar a un diálogo para nombre de carpeta
              _showFolderDialog();
              _refreshItems();
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text("Crear Elemento"),
            onTap: () async {
              Navigator.pop(context); // Cierra el menú
              // Navega al formulario y espera el resultado
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddDocumentScreen()),
              );
              // Verificamos si el widget sigue en el árbol antes de usar el contexto o el estado
              if (!mounted) return;
              // Si regresó con 'true', refrescamos la lista
              if (result == true) _refreshItems();
            },
          ),
        ],
      ),
    );
  }

  void _showFolderDialog() {
    final TextEditingController folderController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nueva Carpeta"),
        content: TextField(
          controller: folderController,
          maxLength: 32, // Regla de negocio: Máximo 32 caracteres
          inputFormatters: [
            // Regla: Letras, números, espacios y guiones
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s\-]')),
          ],
          decoration: const InputDecoration(
            hintText: "Ej: Documentos Personales",
            helperText: "Solo letras, números y guiones",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (folderController.text.trim().isNotEmpty) {
                await DatabaseHelper.instance.insertItem({
                  'id': const Uuid().v4(),
                  'name': folderController.text.trim(),
                  'type': 'folder', // Identificador de carpeta
                  'parent_id': null,
                  'is_active': 1,
                });
                if (!mounted) return;

                Navigator.pop(context);
                _refreshItems(); // Actualiza la lista principal
              }
            },
            child: const Text("Crear"),
          ),
        ],
      ),
    );
  }
}
