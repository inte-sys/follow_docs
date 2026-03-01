import 'package:flutter/material.dart';
import '../widgets/item_tile.dart';
import '../models/item_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Estado persistente de las secciones
  bool _isExpiredOpen = true;
  bool _isAllOpen = false;

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
        stickyHeader: true,
        children: [
          ExpansionPanelList(
            expansionCallback: (index, isExpanded) {
              setState(() {
                if (index == 0)
                  _isExpiredOpen = !isExpanded;
                else
                  _isAllOpen = !isExpanded;
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
                body: const Column(
                    children: []), // Aquí irían las carpetas y documentos
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
            onTap: () {/* Lógica para nombre máx 32 caracteres */},
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text("Crear Elemento"),
            onTap: () {/* Abrir formulario con "Nuevo documento" */},
          ),
        ],
      ),
    );
  }
}
