import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/text_normalizer.dart';
import 'models.dart';

/// Banco gravável do usuário: anotações, favoritos, sinais manuais e buscas.
///
/// Fica separado do banco base para que uma atualização do SignPuddle possa
/// substituir o asset sem apagar nada que o usuário escreveu.
class UserDatabase {
  UserDatabase();

  @visibleForTesting
  UserDatabase.forTesting(Database db) : _db = db;

  static final UserDatabase instance = UserDatabase();

  Database? _db;

  bool get isOpen => _db != null;

  Future<void> open() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Os dados locais não estão disponíveis no navegador.',
      );
    }
    if (_db != null) return;
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'signpuddle', 'user_data.db');
    await Directory(p.dirname(path)).create(recursive: true);
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) => createSchema(db),
    );
  }

  /// Cria as tabelas do usuário. Exposto para testes em memória.
  static Future<void> createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE notes (
        sign_key TEXT PRIMARY KEY,
        custom_title TEXT NOT NULL DEFAULT '',
        custom_terms TEXT NOT NULL DEFAULT '[]',
        tags TEXT NOT NULL DEFAULT '[]',
        note TEXT NOT NULL DEFAULT '',
        search_blob TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_notes_search ON notes(search_blob)',
    );
    await db.execute('''
      CREATE TABLE favorites (
        sign_key TEXT PRIMARY KEY,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE custom_signs (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        terms TEXT NOT NULL DEFAULT '[]',
        sign TEXT NOT NULL,
        sign_kind TEXT NOT NULL DEFAULT 'swu',
        source TEXT,
        note TEXT,
        search_blob TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_custom_search ON custom_signs(search_blob)',
    );
    await db.execute('''
      CREATE TABLE recent_searches (
        query TEXT PRIMARY KEY,
        searched_at TEXT NOT NULL
      )
    ''');
  }

  Future<SignNote?> noteFor(String signKey) async {
    final rows = await _db!.query(
      'notes',
      where: 'sign_key = ?',
      whereArgs: [signKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SignNote.fromRow(rows.first);
  }

  Future<Map<String, SignNote>> notesForKeys(Iterable<String> keys) async {
    final unique = keys.toSet().toList(growable: false);
    if (unique.isEmpty) return const {};
    final placeholders = List.filled(unique.length, '?').join(',');
    final rows = await _db!.rawQuery(
      'SELECT * FROM notes WHERE sign_key IN ($placeholders)',
      unique,
    );
    return {
      for (final row in rows)
        row['sign_key'] as String: SignNote.fromRow(row),
    };
  }

  Future<void> saveNote(SignNote note) async {
    if (note.isEmpty) {
      await _db!.delete('notes', where: 'sign_key = ?', whereArgs: [note.signKey]);
      return;
    }
    final blob = normalizeForSearch(
      [
        note.customTitle,
        ...note.terms,
        ...note.tags,
        note.note,
      ].join(' '),
    );
    await _db!.insert(
      'notes',
      {
        'sign_key': note.signKey,
        'custom_title': note.customTitle.trim(),
        'custom_terms': jsonEncode(note.terms),
        'tags': jsonEncode(note.tags),
        'note': note.note.trim(),
        'search_blob': blob,
        'updated_at': _now(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Set<String>> favoriteKeys() async {
    final rows = await _db!.query('favorites', columns: ['sign_key']);
    return rows.map((row) => row['sign_key'] as String).toSet();
  }

  Future<List<String>> favoriteKeysOrdered() async {
    final rows = await _db!.query(
      'favorites',
      columns: ['sign_key'],
      orderBy: 'created_at DESC',
    );
    return rows.map((row) => row['sign_key'] as String).toList(growable: false);
  }

  Future<void> setFavorite(String signKey, bool favorite) async {
    if (favorite) {
      await _db!.insert(
        'favorites',
        {'sign_key': signKey, 'created_at': _now()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await _db!.delete('favorites', where: 'sign_key = ?', whereArgs: [signKey]);
    }
  }

  Future<List<String>> searchNoteKeys(String normalizedQuery) async {
    if (normalizedQuery.isEmpty) return const [];
    final rows = await _db!.query(
      'notes',
      columns: ['sign_key'],
      where: 'search_blob LIKE ?',
      whereArgs: ['%$normalizedQuery%'],
    );
    return rows.map((row) => row['sign_key'] as String).toList(growable: false);
  }

  Future<List<SignEntry>> searchCustomSigns(String normalizedQuery) async {
    if (normalizedQuery.isEmpty) return const [];
    final rows = await _db!.query(
      'custom_signs',
      where: 'search_blob LIKE ?',
      whereArgs: ['%$normalizedQuery%'],
      orderBy: 'updated_at DESC',
    );
    return rows.map(SignEntry.fromCustomRow).toList(growable: false);
  }

  Future<List<SignEntry>> customSigns() async {
    final rows = await _db!.query('custom_signs', orderBy: 'updated_at DESC');
    return rows.map(SignEntry.fromCustomRow).toList(growable: false);
  }

  Future<SignEntry?> customSignById(String id) async {
    final rows = await _db!.query(
      'custom_signs',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SignEntry.fromCustomRow(rows.first);
  }

  Future<SignEntry> saveCustomSign({
    String? id,
    required String title,
    required List<String> terms,
    required String sign,
    required SignKind signKind,
    String? source,
    String? note,
  }) async {
    final now = _now();
    final existing = id == null ? null : await customSignById(id);
    final resolvedId =
        id ?? DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final resolvedTitle = title.trim().isEmpty
        ? (terms.isNotEmpty ? terms.first : 'Sinal sem título')
        : title.trim();
    final blob = normalizeForSearch(
      [resolvedTitle, ...terms, source ?? '', note ?? ''].join(' '),
    );
    await _db!.insert(
      'custom_signs',
      {
        'id': resolvedId,
        'title': resolvedTitle,
        'terms': jsonEncode(terms),
        'sign': sign.trim(),
        'sign_kind': signKind == SignKind.fsw ? 'fsw' : 'swu',
        'source': source?.trim(),
        'note': note?.trim(),
        'search_blob': blob,
        'created_at': existing?.createdAt?.toIso8601String() ?? now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return (await customSignById(resolvedId))!;
  }

  Future<void> deleteCustomSign(String id) async {
    await _db!.transaction((txn) async {
      await txn.delete('custom_signs', where: 'id = ?', whereArgs: [id]);
      await txn.delete(
        'favorites',
        where: 'sign_key = ?',
        whereArgs: ['custom:$id'],
      );
    });
  }

  Future<List<String>> recentSearches({int limit = 10}) async {
    final rows = await _db!.query(
      'recent_searches',
      orderBy: 'searched_at DESC',
      limit: limit,
    );
    return rows.map((row) => row['query'] as String).toList(growable: false);
  }

  Future<void> addRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    await _db!.insert(
      'recent_searches',
      {'query': trimmed, 'searched_at': _now()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _db!.execute('''
      DELETE FROM recent_searches
      WHERE query NOT IN (
        SELECT query FROM recent_searches
        ORDER BY searched_at DESC
        LIMIT 10
      )
    ''');
  }

  Future<void> clearRecentSearches() async {
    await _db!.delete('recent_searches');
  }

  Future<void> removeRecentSearch(String query) async {
    await _db!.delete(
      'recent_searches',
      where: 'query = ?',
      whereArgs: [query],
    );
  }

  Future<Map<String, Object?>> exportBundle() async {
    final notes = await _db!.query('notes');
    final favorites = await _db!.query('favorites');
    final custom = await _db!.query('custom_signs');
    return {
      'app': 'Escrita de Libras',
      'version': 1,
      'exported_at': _now(),
      'notes': notes,
      'favorites': favorites,
      'custom_signs': custom,
    };
  }

  Future<Map<String, int>> importBundle(Map<String, dynamic> bundle) async {
    final notes = bundle['notes'];
    final favorites = bundle['favorites'];
    final custom = bundle['custom_signs'];
    var noteCount = 0;
    var favoriteCount = 0;
    var customCount = 0;
    await _db!.transaction((txn) async {
      if (notes is List) {
        for (final item in notes.whereType<Map>()) {
          await txn.insert(
            'notes',
            item.cast<String, Object?>(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          noteCount++;
        }
      }
      if (favorites is List) {
        for (final item in favorites.whereType<Map>()) {
          await txn.insert(
            'favorites',
            item.cast<String, Object?>(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          favoriteCount++;
        }
      }
      if (custom is List) {
        for (final item in custom.whereType<Map>()) {
          await txn.insert(
            'custom_signs',
            item.cast<String, Object?>(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          customCount++;
        }
      }
    });
    return {
      'notes': noteCount,
      'favorites': favoriteCount,
      'custom_signs': customCount,
    };
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static String _now() => DateTime.now().toUtc().toIso8601String();
}
