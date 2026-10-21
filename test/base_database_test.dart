import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:escrita_de_libras/data/base_database.dart';

Future<Database> _createBaseDatabase() async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.execute('''
    CREATE TABLE signs (
      id INTEGER PRIMARY KEY,
      title TEXT NOT NULL,
      swu TEXT NOT NULL,
      is_signtext INTEGER NOT NULL DEFAULT 0,
      source TEXT,
      description TEXT,
      signtext TEXT,
      detail_json TEXT,
      user TEXT,
      created_at TEXT,
      updated_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE terms (
      sign_id INTEGER NOT NULL,
      term TEXT NOT NULL,
      term_norm TEXT NOT NULL,
      position INTEGER NOT NULL,
      is_title INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (sign_id, term)
    )
  ''');
  await db.execute('''
    CREATE VIRTUAL TABLE terms_fts USING fts5(
      term_norm,
      content='terms',
      content_rowid='rowid',
      tokenize='unicode61 remove_diacritics 2'
    )
  ''');

  const signs = [
    (1, 'Água', '𝠀aqua', 'Fonte A', 'Líquido', ''),
    (2, 'Casa de banho', '𝠀banho', 'Fonte B', '', ''),
    (3, 'Casa', '𝠀casa', 'Fonte C', '', ''),
  ];
  for (final sign in signs) {
    await db.insert('signs', {
      'id': sign.$1,
      'title': sign.$2,
      'swu': sign.$3,
      'source': sign.$4,
      'description': sign.$5,
      'user': 'colaborador',
      'created_at': '2020-01-01T00:00:00Z',
      'updated_at': '2021-01-01T00:00:00Z',
    });
  }

  const terms = [
    (1, 'água', 'agua', 0),
    (1, 'water', 'water', 1),
    (2, 'casa de banho', 'casa de banho', 0),
    (2, 'banheiro', 'banheiro', 1),
    (3, 'casa', 'casa', 0),
  ];
  for (final term in terms) {
    await db.insert('terms', {
      'sign_id': term.$1,
      'term': term.$2,
      'term_norm': term.$3,
      'position': term.$4,
      'is_title': term.$4 == 0 ? 1 : 0,
    });
  }
  await db.execute("INSERT INTO terms_fts(terms_fts) VALUES ('rebuild')");
  await db.execute('''
    CREATE TABLE sign_images (
      sign_id INTEGER PRIMARY KEY,
      svg BLOB NOT NULL
    )
  ''');
  await db.insert('sign_images', {
    'sign_id': 1,
    'svg': Uint8List.fromList('<svg/>'.codeUnits),
  });
  return db;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late Database db;
  late BaseDatabase base;

  setUp(() async {
    db = await _createBaseDatabase();
    base = BaseDatabase.forTesting(db);
  });

  tearDown(() async {
    await base.close();
  });

  test('busca exata normaliza acentos', () async {
    final results = await base.search('água');
    expect(results, hasLength(1));
    expect(results.first.title, 'Água');
    expect(results.first.terms, ['água', 'water']);
    expect(results.first.description, 'Líquido');
    expect(results.first.sourceLabel, 'Fonte A');
  });

  test('busca por prefixo', () async {
    final results = await base.search('agu');
    expect(results.map((entry) => entry.sourceId), contains(1));
  });

  test('FTS encontra token no meio de uma expressão', () async {
    final results = await base.search('banho');
    expect(results.map((entry) => entry.sourceId), contains(2));
  });

  test('fallback por substring', () async {
    final results = await base.search('asa');
    expect(results.map((entry) => entry.sourceId), containsAll([2, 3]));
  });

  test('entradas por ids preservam a ordem', () async {
    final entries = await base.entriesByIds([3, 1]);
    expect(entries.map((entry) => entry.sourceId), [3, 1]);
  });

  test('lê blob de imagem quando a tabela existe', () async {
    final bytes = await base.imageBlob(1);
    expect(bytes, isNotNull);
    expect(String.fromCharCodes(bytes!), '<svg/>');
    expect(await base.imageBlob(2), isNull);
  });

  test('sinal aleatório devolve uma entrada com desenho', () async {
    final entry = await base.randomEntry();
    expect(entry, isNotNull);
    expect(entry!.hasImage, isTrue);
  });
}
