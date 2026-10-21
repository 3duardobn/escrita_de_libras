/// Informações centrais do app e do dicionário sincronizado.
abstract final class AppInfo {
  static const appName = 'Escrita de Libras';
  static const tagline = 'Dicionário de Libras em SignWriting';

  static const dictionaryName = 'bzs-BR-dictionary-public';
  static const dictionaryLabel = 'Libras (Brasil)';
  static const dictionaryIso = 'bzs';

  static const signPuddleClient = 'https://signpuddle.com/client/';
  static const signPuddleServer = 'https://signpuddle.com/server';

  static const databaseAsset = 'assets/signpuddle.db';
  static const databaseVersion = 1;
}
