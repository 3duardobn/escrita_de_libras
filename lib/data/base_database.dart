import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/app_info.dart';
import '../core/text_normalizer.dart';
import 'models.dart';

/// Banco base (somente leitura), copiado do asset para o armazenamento do app.
class BaseDatabase {
  BaseDatabase();

  @visibleForTesting
  BaseDatabase.forTesting(Database db) : _db = db;

  static final BaseDatabase instance = BaseDatabase();

  Database? _db;
  Map<String, String> _meta = const {};
  List<String> _suggestionTerms = const [];
  bool? _hasImageTable;

  bool get isOpen => _db != null;
  Map<String, String> get meta => _meta;
  List<String> get suggestionTerms => _suggestionTerms;

  Future<void> open() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'O SQLite local não está disponível no navegador. '
        'Use a versão Android ou Linux.',
      );
    }
    if (_db != null) return;

    final dir = await getApplicationSupportDirectory();
    final databaseDir = Directory(p.join(dir.path, 'signpuddle'));
    await databaseDir.create(recursive: true);
    final databasePath = p.join(databaseDir.path, 'base.db');

    final shouldCopy = await _shouldCopyAsset(databasePath);
    if (shouldCopy) {
      final data = await rootBundle.load(AppInfo.databaseAsset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final tmp = File('$databasePath.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(databasePath);
    }

    _db = await openDatabase(databasePath, readOnly: true);
    await _loadMeta();
    await _loadSuggestionTerms();
  }

  Future<bool> _shouldCopyAsset(String path) async {
    final file = File(path);
    if (!await file.exists()) return true;
    try {
      final existing = await openDatabase(path, readOnly: true);
      final version = await existing.getVersion();
      await existing.close();
      return version != AppInfo.databaseVersion;
    } catch (_) {
      return true;
    }
  }

  Future<void> _loadMeta() async {
    final rows = await _db!.query('meta');
    _meta = {
      for (final row in rows)
        row['key'] as String: (row['value'] as String?) ?? '',
    };
  }

  Future<void> _loadSuggestionTerms() async {
    final rows = await _db!.rawQuery('''
      SELECT term
      FROM terms
      GROUP BY term_norm
      ORDER BY MIN(is_title) DESC, MIN(position) ASC, term COLLATE NOCASE ASC
    ''');
    _suggestionTerms = rows
        .map((row) => row['term'] as String?)
        .whereType<String>()
        .where((term) => term.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<List<SignEntry>> search(
    String query, {
    int limit = 80,
  }) async {
    final normalized = normalizeForSearch(query);
    if (normalized.isEmpty) return const [];

    final exact = await _searchExact(normalized, limit);
    if (exact.isNotEmpty) return exact;

    final prefix = await _searchPrefix(normalized, limit);
    if (prefix.isNotEmpty) return prefix;

    final fts = await _searchFts(normalized, limit);
    if (fts.isNotEmpty) return fts;

    return _searchContains(normalized, limit);
  }

  Future<List<SignEntry>> _searchExact(String normalized, int limit) async {
    final rows = await _db!.rawQuery(
      '''
      SELECT s.*
      FROM signs s
      JOIN terms t ON t.sign_id = s.id
      WHERE t.term_norm = ?
      GROUP BY s.id
      ORDER BY LENGTH(s.title) ASC, s.title COLLATE NOCASE ASC
      LIMIT ?
      ''',
      [normalized, limit],
    );
    return _attachTerms(rows);
  }

  Future<List<SignEntry>> _searchPrefix(String normalized, int limit) async {
    final rows = await _db!.rawQuery(
      '''
      SELECT s.*, MIN(LENGTH(t.term)) AS match_len, MIN(t.position) AS match_pos
      FROM signs s
      JOIN terms t ON t.sign_id = s.id
      WHERE t.term_norm LIKE ?
      GROUP BY s.id
      ORDER BY match_len ASC, match_pos ASC,
               LENGTH(s.title) ASC, s.title COLLATE NOCASE ASC
      LIMIT ?
      ''',
      ['$normalized%', limit],
    );
    return _attachTerms(rows);
  }

  Future<List<SignEntry>> _searchFts(String normalized, int limit) async {
    final match = ftsQueryFor(normalized);
    if (match.isEmpty) return const [];
    try {
      final rows = await _db!.rawQuery(
        '''
        SELECT s.*, MIN(f.rank) AS rank
        FROM terms_fts f
        JOIN terms t ON t.rowid = f.rowid
        JOIN signs s ON s.id = t.sign_id
        WHERE terms_fts MATCH ?
        GROUP BY s.id
        ORDER BY rank ASC
        LIMIT ?
        ''',
        [match, limit],
      );
      return _attachTerms(rows);
    } catch (_) {
      return const [];
    }
  }

  Future<List<SignEntry>> _searchContains(String normalized, int limit) async {
    final rows = await _db!.rawQuery(
      '''
      SELECT s.*, MIN(LENGTH(t.term)) AS match_len
      FROM signs s
      JOIN terms t ON t.sign_id = s.id
      WHERE t.term_norm LIKE ?
      GROUP BY s.id
      ORDER BY match_len ASC, LENGTH(s.title) ASC, s.title COLLATE NOCASE ASC
      LIMIT ?
      ''',
      ['%$normalized%', limit],
    );
    return _attachTerms(rows);
  }

  Future<List<SignEntry>> _attachTerms(List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return const [];
    final ids = rows.map((row) => row['id'] as int).toList(growable: false);
    final placeholders = List.filled(ids.length, '?').join(',');
    final termRows = await _db!.rawQuery(
      '''
      SELECT sign_id, term
      FROM terms
      WHERE sign_id IN ($placeholders)
      ORDER BY sign_id, position
      ''',
      ids,
    );
    final bySign = <int, List<String>>{};
    for (final row in termRows) {
      final signId = row['sign_id'] as int;
      final term = row['term'] as String?;
      if (term != null && term.trim().isNotEmpty) {
        bySign.putIfAbsent(signId, () => []).add(term);
      }
    }
    return rows
        .map(
          (row) => SignEntry.fromBaseRow(
            row,
            terms: bySign[row['id'] as int] ?? const [],
          ),
        )
        .toList(growable: false);
  }

  Future<SignEntry?> entryById(int id) async {
    final rows = await _db!.query('signs', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final entries = await _attachTerms(rows);
    return entries.firstOrNull;
  }

  Future<List<SignEntry>> entriesByIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final unique = ids.toSet().toList(growable: false);
    final placeholders = List.filled(unique.length, '?').join(',');
    final rows = await _db!.rawQuery(
      'SELECT * FROM signs WHERE id IN ($placeholders)',
      unique,
    );
    final entries = await _attachTerms(rows);
    final byId = {for (final entry in entries) entry.sourceId!: entry};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<SignEntry?> randomEntry() async {
    final rows = await _db!.rawQuery(
      "SELECT * FROM signs WHERE swu <> '' ORDER BY RANDOM() LIMIT 1",
    );
    if (rows.isEmpty) return null;
    final entries = await _attachTerms(rows);
    return entries.firstOrNull;
  }

  /// Lê o SVG embutido no banco, quando o usuário rodou o downloader com
  /// `--into-db`. Caso contrário devolve `null` e o app busca na rede.
  Future<Uint8List?> imageBlob(int id) async {
    final db = _db;
    if (db == null) return null;
    _hasImageTable ??= await _tableExists('sign_images');
    if (_hasImageTable != true) return null;
    final rows = await db.query(
      'sign_images',
      columns: ['svg'],
      where: 'sign_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['svg'] as Uint8List?;
  }

  Future<bool> _tableExists(String table) async {
    final rows = await _db!.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
      [table],
    );
    return rows.isNotEmpty;
  }

  Future<Map<String, String>> metaData() async {
    if (_meta.isEmpty && _db != null) await _loadMeta();
    return _meta;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
