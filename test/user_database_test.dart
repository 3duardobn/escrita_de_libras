import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:escrita_de_libras/data/models.dart';
import 'package:escrita_de_libras/data/user_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late Database db;
  late UserDatabase user;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await UserDatabase.createSchema(db);
    user = UserDatabase.forTesting(db);
  });

  tearDown(() async {
    await user.close();
  });

  test('salva, pesquisa e apaga anotações', () async {
    const note = SignNote(
      signKey: 'base:1',
      customTitle: 'Minha casa',
      terms: ['moradia', 'lar'],
      tags: ['família'],
      note: 'Uso na aula de terça.',
    );
    await user.saveNote(note);

    final loaded = await user.noteFor('base:1');
    expect(loaded, isNotNull);
    expect(loaded!.customTitle, 'Minha casa');
    expect(loaded.terms, ['moradia', 'lar']);
    expect(loaded.tags, ['família']);

    expect(await user.searchNoteKeys('familia'), ['base:1']);
    expect(await user.searchNoteKeys('moradia'), ['base:1']);
    expect(await user.searchNoteKeys('inexistente'), isEmpty);

    final map = await user.notesForKeys(['base:1', 'base:2']);
    expect(map.keys, ['base:1']);

    await user.saveNote(const SignNote(signKey: 'base:1'));
    expect(await user.noteFor('base:1'), isNull);
  });

  test('favoritos são únicos e ordenados', () async {
    await user.setFavorite('base:1', true);
    await user.setFavorite('base:2', true);
    await user.setFavorite('base:1', true);

    expect(await user.favoriteKeys(), {'base:1', 'base:2'});
    expect(await user.favoriteKeysOrdered(), hasLength(2));

    await user.setFavorite('base:1', false);
    expect(await user.favoriteKeys(), {'base:2'});
  });

  test('sinal manual entra na busca e pode ser editado/excluído', () async {
    final entry = await user.saveCustomSign(
      title: 'Casa da família',
      terms: ['casa', 'moradia'],
      sign: '𝠀manual',
      signKind: SignKind.swu,
      source: 'Criação própria',
      note: 'Sinal que uso em casa.',
    );
    expect(entry.customId, isNotNull);

    final found = await user.searchCustomSigns('moradia');
    expect(found, hasLength(1));
    expect(found.first.title, 'Casa da família');
    expect(found.first.customNote, 'Sinal que uso em casa.');

    final updated = await user.saveCustomSign(
      id: entry.customId,
      title: 'Casa',
      terms: ['casa'],
      sign: '𝠀manual',
      signKind: SignKind.swu,
      note: 'Atualizado.',
    );
    expect(updated.title, 'Casa');
    expect(await user.searchCustomSigns('familia'), isEmpty);

    await user.setFavorite(entry.key, true);
    await user.deleteCustomSign(entry.customId!);
    expect(await user.customSignById(entry.customId!), isNull);
    expect(await user.favoriteKeys(), isEmpty);
  });

  test('buscas recentes mantêm no máximo dez', () async {
    for (var i = 0; i < 12; i++) {
      await user.addRecentSearch('busca $i');
    }
    final recent = await user.recentSearches();
    expect(recent, hasLength(10));
    expect(recent.first, 'busca 11');

    await user.removeRecentSearch('busca 11');
    expect(await user.recentSearches(), isNot(contains('busca 11')));

    await user.clearRecentSearches();
    expect(await user.recentSearches(), isEmpty);
  });

  test('exporta e importa um pacote', () async {
    await user.saveNote(
      const SignNote(signKey: 'base:9', note: 'Anotação de teste.'),
    );
    await user.setFavorite('base:9', true);
    await user.saveCustomSign(
      title: 'Manual',
      terms: ['teste'],
      sign: '𝠀x',
      signKind: SignKind.swu,
    );

    final bundle = await user.exportBundle();
    expect(bundle['app'], 'Escrita de Libras');
    expect(bundle['notes'], hasLength(1));
    expect(bundle['favorites'], hasLength(1));
    expect(bundle['custom_signs'], hasLength(1));

    final counts = await user.importBundle(bundle);
    expect(counts['notes'], 1);
    expect(counts['favorites'], 1);
    expect(counts['custom_signs'], 1);
  });
}
