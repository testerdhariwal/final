import 'dart:io' as io;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/masail.dart';

class DatabaseHelper {
  static Database? _db;

  /// Singleton pattern to get the database instance
  Future<Database> get db async {
    if (_db != null) {
      return _db!;
    }
    _db = await initDb();
    return _db!;
  }

  /// Initialize the SQLite database
  Future<Database> initDb() async {
    io.Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'masail_database.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  /// Create the masail table
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE masail (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        title TEXT, 
        description TEXT, 
        language TEXT
      )
    ''');
  }

  /// Insert a new record - Auto-generates `id`
  Future<int> saveMasail(Masail masail) async {
    var dbClient = await db;
    print('Saving Masail to SQLite: title=${masail.title}, description=${masail.description}, language=${masail.language}');
    return await dbClient.insert(
      'masail',
      {
        'title': masail.title,
        'description': masail.description,
        'language': masail.language,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all records
  Future<List<Masail>> getMasail() async {
    var dbClient = await db;
    List<Map<String, dynamic>> maps = await dbClient.query('masail');

    return List.generate(maps.length, (i) {
      return Masail.fromMap(maps[i]);
    });
  }

  /// Delete a record by ID
  Future<int> deleteMasail(int id) async {
    var dbClient = await db;
    return await dbClient.delete('masail', where: 'id = ?', whereArgs: [id]);
  }

  /// Update an existing record
  Future<int> updateMasail(Masail masail) async {
    var dbClient = await db;
    return await dbClient.update(
      'masail',
      masail.toMap(),
      where: 'id = ?',
      whereArgs: [masail.id],
    );
  }

  /// Count the total records
  Future<int?> queryRowCount() async {
    var dbClient = await db;
    return Sqflite.firstIntValue(await dbClient.rawQuery('SELECT COUNT(*) FROM masail'));
  }

  /// Delete database on reinstall (Optional)
  Future<void> deleteDatabaseOnReinstall() async {
    io.Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'masail_database.db');

    if (await databaseExists(path)) {
      await deleteDatabase(path);
    }
  }

  Future<List<Masail>> getMasailByLanguage(String language) async {
    final trimmedLanguage = language.trim();
    if (trimmedLanguage.isEmpty) {
      print('Warning: Empty language provided to getMasailByLanguage. Returning empty list.');
      return [];
    }
    var dbClient = await db;
    print('Fetching Masail from SQLite for language: $trimmedLanguage');
    List<Map<String, dynamic>> maps = await dbClient.query(
      'masail',
      where: 'language = ?',
      whereArgs: [trimmedLanguage],
    );
    print('Fetched ${maps.length} Masail from SQLite.');
    return List.generate(maps.length, (i) {
      return Masail.fromMap(maps[i]);
    });
  }

  Future<void> deleteAllMasail() async {
    final dbClient = await db;
    await dbClient.rawDelete('DELETE FROM masail');
  }
}
