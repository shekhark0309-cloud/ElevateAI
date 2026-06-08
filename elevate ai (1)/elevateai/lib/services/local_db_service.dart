import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class LocalDatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'elevateai_offline.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_opportunities (
            id TEXT PRIMARY KEY,
            data TEXT,
            cached_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE cached_notifications (
            id TEXT PRIMARY KEY,
            data TEXT,
            cached_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE cached_dna (
            student_id TEXT PRIMARY KEY,
            data TEXT,
            cached_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE pending_actions (
            id TEXT PRIMARY KEY,
            action_type TEXT,
            payload TEXT,
            created_at INTEGER
          )
        ''');
      },
    );
  }

  Future<void> cacheData(String table, String id, Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      table,
      {
        table == 'cached_dna' ? 'student_id' : 'id': id,
        'data': jsonEncode(data),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> addPendingAction(String type, Map<String, dynamic> payload) async {
    final db = await database;
    await db.insert('pending_actions', {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'action_type': type,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> sync() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return;

    final db = await database;
    final pending = await db.query('pending_actions', orderBy: 'created_at ASC');

    final supabase = Supabase.instance.client;

    for (var action in pending) {
      final type = action['action_type'] as String;
      final payload = jsonDecode(action['payload'] as String) as Map<String, dynamic>;

      try {
        if (type == 'submit_peer_rating') {
          await supabase.rpc('submit_peer_rating', params: payload);
        } else if (type == 'award_badge') {
          await supabase.rpc('award_badge', params: payload);
        }
        // Add more action types as needed

        // If success, remove from pending
        await db.delete('pending_actions', where: 'id = ?', whereArgs: [action['id']]);
      } catch (e) {
        // Log error and maybe retry later
        print('Offline sync failed for action ${action['id']}: $e');
      }
    }
  }
}
