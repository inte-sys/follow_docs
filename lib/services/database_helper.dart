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
    await db.execute('''
      CREATE TABLE items (
        id TEXT PRIMARY KEY,
        parent_id TEXT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        doc_type TEXT,
        expiration_date TEXT,
        reminder_type TEXT,
        reminder_value INTEGER,
        reminder_unit TEXT,
        is_active INTEGER DEFAULT 1
      )
    ''');
  }

  Future<int> insertItem(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert('items', row);
  }

  Future<List<Map<String, dynamic>>> queryAllItems() async {
    Database db = await instance.database;
    // Ordenamos carpetas primero
    return await db.query('items', orderBy: "type DESC, name ASC");
  }

// Añade estos métodos si no los tienes
  Future<int> updateItem(Map<String, dynamic> row) async {
    Database db = await instance.database;
    String id = row['id'];
    return await db.update('items', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteItem(String id) async {
    Database db = await instance.database;
    return await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }
}
