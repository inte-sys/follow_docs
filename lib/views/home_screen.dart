import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../models/item_model.dart';
import '../widgets/item_tile.dart';
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
  bool _isAllOpen = true;
  bool _isExpiredOpen = true;

  @override
  void initState() {
    super.initState();
    _refreshItems();
  }

  Future<void> _refreshItems() async {
    final data = await DatabaseHelper.instance.queryAllItems();

    // VOLCADO DE DEBUG: Copia esto de tu consola si falla
    debugPrint("--- VOLCADO COMPLETO DE BASE DE DATOS ---");
    for (var row in data) {
      debugPrint(row.toString());
    }
    debugPrint("-----------------------------------------");

    setState(() {
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

  void _showFolderDialog() {
    final TextEditingController folderController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nueva Carpeta"),
        content: TextField(
          controller: folderController,
          maxLength: 32,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s\-]'))
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (folderController.text.trim().isNotEmpty) {
                await DatabaseHelper.instance.insertItem({
                  'id': const Uuid().v4(),
                  'name': folderController.text.trim(),
                  'type': 'folder',
                  'is_active': 1,
                });
                if (!mounted) return;
                Navigator.pop(context);
                _refreshItems();
              }
            },
            child: const Text("Crear"),
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
              final res = await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AddDocumentScreen()));
              if (res == true) _refreshItems();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Follow Docs")),
      body: RefreshIndicator(
        // Para que puedas arrastrar hacia abajo y refrescar
        onRefresh: _refreshItems,
        child: ListView(
          // Cambiamos SingleChildScrollView por ListView
          children: [
            ExpansionPanelList(
              expansionCallback: (index, isExpanded) {
                setState(() {
                  if (index == 0) {
                    _isExpiredOpen = isExpanded;
                  } else {
                    _isAllOpen = isExpanded;
                  }
                });
              },
              children: [
                ExpansionPanel(
                  headerBuilder: (context, isExp) =>
                      const ListTile(title: Text("Vencidos")),
                  body: Column(
                    children: _items
                        .where((i) => i.isExpired)
                        .map((item) =>
                            ItemTile(item: item, onTap: _refreshItems))
                        .toList(),
                  ),
                  isExpanded: _isExpiredOpen,
                ),
                ExpansionPanel(
                  headerBuilder: (context, isExp) =>
                      const ListTile(title: Text("Todos")),
                  body: Column(
                    // <--- CAMBIA ListView.builder por Column aquí
                    children: _items
                        .map((item) =>
                            ItemTile(item: item, onTap: _refreshItems))
                        .toList(),
                  ),
                  isExpanded: _isAllOpen,
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateOptions,
        child: const Icon(Icons.add),
      ),
    );
  }
}
