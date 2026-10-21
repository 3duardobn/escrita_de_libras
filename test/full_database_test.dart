import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:escrita_de_libras/data/base_database.dart';
import 'package:escrita_de_libras/data/models.dart';
import 'package:escrita_de_libras/data/user_database.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory temp;
  late PathProviderPlatform previous;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('escrita_de_libras_test_');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(temp.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = previous;
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('abre o asset real e pesquisa no banco completo', () async {
    final base = BaseDatabase();
    await base.open();

    expect(base.meta['dictionary'], 'bzs-BR-dictionary-public');
    expect(int.parse(base.meta['entries']!), 25611);
    expect(base.suggestionTerms.length, greaterThan(10000));

    final agua = await base.search('água');
    expect(agua, isNotEmpty);
    expect(
      agua.any((entry) => entry.terms.any((term) => term.contains('gua'))),
      isTrue,
    );
    expect(agua.every((entry) => entry.sign.isNotEmpty), isTrue);

    final casa = await base.search('casa');
    expect(casa, isNotEmpty);
    expect(casa.every((entry) => entry.hasImage), isTrue);

    expect(await base.imageBlob(595), isNull);
    await base.close();
  });

  test('abre o banco do usuário ao lado do banco base', () async {
    final base = BaseDatabase();
    await base.open();
    final user = UserDatabase();
    await user.open();

    final entry = await user.saveCustomSign(
      title: 'Teste',
      terms: ['teste'],
      sign: '𝠀teste',
      signKind: SignKind.swu,
    );
    expect(entry.customId, isNotNull);
    expect((await user.searchCustomSigns('teste')).first.title, 'Teste');

    await user.saveNote(
      const SignNote(signKey: 'base:595', note: 'Anotação no banco real.'),
    );
    expect(await user.noteFor('base:595'), isNotNull);

    await user.close();
    await base.close();
  });
}
