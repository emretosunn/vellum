import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Çevrimdışı okuma için yerel SQLite veritabanı servisi.
///
/// Not: Bu servis mevcut Supabase/Hive akışını bozmaz; Aşama 1 kapsamında
/// sadece tablo altyapısını hazırlar.
class LocalDatabaseService {
  static const String _dbName = 'vellum_offline.db';
  static const int _dbVersion = 2;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = '${docsDir.path}/$_dbName';

    return openDatabase(
      dbPath,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createOfflineReadTables(db);
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_books (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author_name TEXT NOT NULL,
        local_cover_path TEXT,
        downloaded_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_chapters (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        FOREIGN KEY (book_id) REFERENCES offline_books(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_offline_chapters_book_id_order
      ON offline_chapters(book_id, order_index)
    ''');

    await _createOfflineReadTables(db);
  }

  Future<void> _createOfflineReadTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_read_events (
        user_id TEXT NOT NULL,
        book_id TEXT NOT NULL,
        completed_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (user_id, book_id)
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_offline_read_events_synced_completed_at
      ON offline_read_events(synced, completed_at DESC)
    ''');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}

final localDatabaseServiceProvider = Provider<LocalDatabaseService>((ref) {
  final service = LocalDatabaseService();
  ref.onDispose(() {
    service.close();
  });
  return service;
});

