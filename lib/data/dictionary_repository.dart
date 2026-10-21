import 'dart:convert';

import '../core/text_normalizer.dart';
import 'base_database.dart';
import 'models.dart';
import 'user_database.dart';

/// Junta o dicionário base (somente leitura) com os dados do usuário.
class DictionaryRepository {
  DictionaryRepository({BaseDatabase? base, UserDatabase? user})
    : base = base ?? BaseDatabase.instance,
      user = user ?? UserDatabase.instance;

  final BaseDatabase base;
  final UserDatabase user;

  Future<void> init() async {
    if (!base.isOpen) await base.open();
    if (!user.isOpen) await user.open();
  }

  Future<List<SignEntry>> search(String query) async {
    final normalized = normalizeForSearch(query);
    if (normalized.isEmpty) return const [];

    final baseResults = await base.search(query);
    final seen = baseResults.map((entry) => entry.key).toSet();

    // Anotações pessoais também são pesquisáveis.
    final noteKeys = await user.searchNoteKeys(normalized);
    final noteBaseIds = <int>[];
    for (final key in noteKeys) {
      if (!key.startsWith('base:')) continue;
      final id = int.tryParse(key.substring('base:'.length));
      if (id != null && !seen.contains(key)) noteBaseIds.add(id);
    }
    final notedEntries = await base.entriesByIds(noteBaseIds);
    seen.addAll(notedEntries.map((entry) => entry.key));

    final custom = (await user.searchCustomSigns(normalized))
        .where((entry) => seen.add(entry.key))
        .toList(growable: false);

    // Sinais manuais primeiro (são do usuário), depois os do dicionário.
    return [...custom, ...baseResults, ...notedEntries];
  }

  Future<SignEntry?> entryByKey(String key) async {
    if (key.startsWith('base:')) {
      final id = int.tryParse(key.substring('base:'.length));
      return id == null ? null : base.entryById(id);
    }
    if (key.startsWith('custom:')) {
      return user.customSignById(key.substring('custom:'.length));
    }
    return null;
  }

  Future<List<SignEntry>> favoriteEntries() async {
    final keys = await user.favoriteKeysOrdered();
    if (keys.isEmpty) return const [];
    final entries = <SignEntry>[];
    for (final key in keys) {
      final entry = await entryByKey(key);
      if (entry != null) entries.add(entry);
    }
    return entries;
  }

  Future<List<SignEntry>> customSigns() => user.customSigns();

  Future<SignEntry?> randomEntry() => base.randomEntry();

  Future<SignNote?> noteFor(SignEntry entry) async {
    if (entry.isCustom) return null;
    return user.noteFor(entry.key);
  }

  Future<void> saveNote(SignNote note) => user.saveNote(note);

  Future<void> toggleFavorite(SignEntry entry) async {
    final keys = await user.favoriteKeys();
    await user.setFavorite(entry.key, !keys.contains(entry.key));
  }

  Future<SignEntry> saveCustomSign({
    String? id,
    required String title,
    required List<String> terms,
    required String sign,
    required SignKind signKind,
    String? source,
    String? note,
  }) {
    return user.saveCustomSign(
      id: id,
      title: title,
      terms: terms,
      sign: sign,
      signKind: signKind,
      source: source,
      note: note,
    );
  }

  Future<void> deleteCustomSign(String id) => user.deleteCustomSign(id);

  Future<List<String>> recentSearches() => user.recentSearches();

  Future<void> addRecentSearch(String query) => user.addRecentSearch(query);

  Future<void> clearRecentSearches() => user.clearRecentSearches();

  Future<void> removeRecentSearch(String query) => user.removeRecentSearch(query);

  Future<Map<String, String>> meta() => base.metaData();

  Future<List<String>> suggestionTerms() async {
    if (!base.isOpen) await base.open();
    return base.suggestionTerms;
  }

  Future<String> exportJson() async {
    final bundle = await user.exportBundle();
    return const JsonEncoder.withIndent('  ').convert(bundle);
  }

  Future<Map<String, int>> importJson(String source) async {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('O JSON precisa ser um objeto.');
    }
    if (decoded['app'] != 'Escrita de Libras') {
      throw const FormatException(
        'Este arquivo não parece ter sido exportado pelo Escrita de Libras.',
      );
    }
    return user.importBundle(decoded);
  }
}
