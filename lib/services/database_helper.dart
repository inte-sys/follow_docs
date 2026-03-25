import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('follow_docs.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    try {
      await db.execute('''
        CREATE TABLE items (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          type TEXT NOT NULL, -- 'folder' o 'document'
          doc_type TEXT,      -- 'Pasaporte', 'Licencia', etc.
          expiration_date TEXT,
          is_active INTEGER DEFAULT 1,
          parent_id TEXT,
          notif_value INTEGER DEFAULT 7,
          notif_unit TEXT DEFAULT 'Días',
          FOREIGN KEY (parent_id) REFERENCES items (id) ON DELETE CASCADE
        )
      ''');
    } catch (e) {
      throw Exception("Error al crear las tablas: $e");
    }
  }

  Future<int> insertItem(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert('items', row);
  }

  Future<int> updateItem(Map<String, dynamic> row) async {
    Database db = await instance.database;
    String id = row['id'];
    return await db.update('items', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteItem(String id) async {
    Database db = await instance.database;
    return await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  /// Consulta principal que maneja navegación por carpetas y búsqueda global
  Future<List<Map<String, dynamic>>> getItems(
      {String? parentId, String? search}) async {
    final db = await instance.database;

    if (search != null && search.isNotEmpty) {
      // Búsqueda global (ignora carpetas para encontrar el archivo)
      return await db.query(
        'items',
        where: 'name LIKE ?',
        whereArgs: ['%$search%'],
        orderBy: 'type DESC, LOWER(name) ASC',
      );
    } else {
      // Navegación normal dentro de una carpeta específica
      return await db.query(
        'items',
        where: parentId == null ? 'parent_id IS NULL' : 'parent_id = ?',
        whereArgs: parentId == null ? [] : [parentId],
        orderBy: 'type DESC, LOWER(name) ASC',
      );
    }
  }
}
