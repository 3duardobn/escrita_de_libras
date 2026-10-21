import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/text_normalizer.dart';
import '../data/dictionary_repository.dart';
import '../data/models.dart';
import '../services/sign_image_service.dart';

/// Estado global do app. As telas escutam via `ListenableBuilder`.
class AppState extends ChangeNotifier {
  AppState({DictionaryRepository? repository})
    : repository = repository ?? DictionaryRepository();

  static final AppState instance = AppState();

  final DictionaryRepository repository;

  bool _initialized = false;
  Object? _startupError;
  bool _searching = false;
  String _query = '';
  String? _lastQuery;
  String? _error;
  List<SignEntry> _results = const [];
  List<String> _allTerms = const [];
  List<String> _recentSearches = const [];
  Set<String> _favorites = <String>{};
  Map<String, String> _meta = const {};
  Map<String, SignNote> _notes = const {};
  ThemeMode _themeMode = ThemeMode.system;
  int _searchToken = 0;
  SharedPreferences? _prefs;

  bool get initialized => _initialized;
  Object? get startupError => _startupError;
  bool get searching => _searching;
  String get query => _query;
  String? get lastQuery => _lastQuery;
  String? get error => _error;
  List<SignEntry> get results => _results;
  List<String> get recentSearches => _recentSearches;
  Set<String> get favorites => _favorites;
  Map<String, String> get meta => _meta;
  ThemeMode get themeMode => _themeMode;

  int get entryCount => int.tryParse(_meta['entries'] ?? '') ?? 0;
  int get termCount => int.tryParse(_meta['terms'] ?? '') ?? 0;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final savedTheme = _prefs?.getString('theme_mode');
    _themeMode = switch (savedTheme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    try {
      await repository.init();
      _meta = await repository.meta();
      _allTerms = await repository.suggestionTerms();
      _favorites = await repository.user.favoriteKeys();
      _recentSearches = await repository.recentSearches();
    } catch (error) {
      _startupError = error;
    }
    _initialized = true;
    notifyListeners();
  }

  List<String> suggestionsFor(String prefix) =>
      filterSuggestions(_allTerms, prefix);

  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final token = ++_searchToken;
    _query = trimmed;
    _searching = true;
    _error = null;
    notifyListeners();

    try {
      final results = await repository.search(trimmed);
      if (token != _searchToken) return;
      _results = results;
      _lastQuery = trimmed;
      _searching = false;
      _notes = await repository.user.notesForKeys(
        results.where((entry) => !entry.isCustom).map((entry) => entry.key),
      );
      await repository.addRecentSearch(trimmed);
      _recentSearches = await repository.recentSearches();
      notifyListeners();
    } catch (error) {
      if (token != _searchToken) return;
      _searching = false;
      _error = 'Não foi possível pesquisar: $error';
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchToken++;
    _query = '';
    _lastQuery = null;
    _results = const [];
    _searching = false;
    _error = null;
    notifyListeners();
  }

  void removeRecent(String query) {
    _recentSearches = _recentSearches
        .where((item) => item != query)
        .toList(growable: false);
    repository.removeRecentSearch(query);
    notifyListeners();
  }

  Future<void> clearRecentSearches() async {
    await repository.clearRecentSearches();
    _recentSearches = const [];
    notifyListeners();
  }

  bool isFavorite(SignEntry entry) => _favorites.contains(entry.key);

  Future<void> toggleFavorite(SignEntry entry) async {
    await repository.toggleFavorite(entry);
    if (_favorites.contains(entry.key)) {
      _favorites = {..._favorites}..remove(entry.key);
    } else {
      _favorites = {..._favorites, entry.key};
    }
    notifyListeners();
  }

  Future<List<SignEntry>> favoriteEntries() => repository.favoriteEntries();

  SignNote? cachedNote(SignEntry entry) =>
      entry.isCustom ? null : _notes[entry.key];

  Future<SignNote?> noteFor(SignEntry entry) async {
    if (entry.isCustom) return null;
    final note = await repository.noteFor(entry);
    if (note != null) {
      _notes = {..._notes, entry.key: note};
    } else {
      _notes = {..._notes}..remove(entry.key);
    }
    return note;
  }

  Future<void> saveNote(SignNote note) async {
    await repository.saveNote(note);
    if (note.isEmpty) {
      _notes = {..._notes}..remove(note.signKey);
    } else {
      _notes = {..._notes, note.signKey: note};
    }
    notifyListeners();
  }

  Future<SignEntry?> randomEntry() => repository.randomEntry();

  Future<SignEntry> saveCustomSign({
    String? id,
    required String title,
    required List<String> terms,
    required String sign,
    required SignKind signKind,
    String? source,
    String? note,
  }) async {
    final entry = await repository.saveCustomSign(
      id: id,
      title: title,
      terms: terms,
      sign: sign,
      signKind: signKind,
      source: source,
      note: note,
    );
    if (_lastQuery != null && _lastQuery!.isNotEmpty) {
      final results = await repository.search(_lastQuery!);
      _results = results;
    }
    notifyListeners();
    return entry;
  }

  Future<void> deleteCustomSign(SignEntry entry) async {
    if (entry.customId == null) return;
    await repository.deleteCustomSign(entry.customId!);
    _favorites = {..._favorites}..remove(entry.key);
    if (_lastQuery != null && _lastQuery!.isNotEmpty) {
      _results = await repository.search(_lastQuery!);
    }
    notifyListeners();
  }

  Future<String> exportData() => repository.exportJson();

  Future<Map<String, int>> importData(String json) async {
    final counts = await repository.importJson(json);
    _favorites = await repository.user.favoriteKeys();
    _recentSearches = await repository.recentSearches();
    if (_lastQuery != null && _lastQuery!.isNotEmpty) {
      _results = await repository.search(_lastQuery!);
      _notes = await repository.user.notesForKeys(
        _results.where((entry) => !entry.isCustom).map((entry) => entry.key),
      );
    }
    notifyListeners();
    return counts;
  }

  Future<void> toggleTheme() async {
    _themeMode = switch (_themeMode) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    };
    await _saveTheme();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await _saveTheme();
  }

  Future<void> _saveTheme() async {
    await _prefs?.setString('theme_mode', switch (_themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
    notifyListeners();
  }

  Future<int> imageCacheSize() => SignImageService.instance.cacheSizeBytes();

  Future<void> clearImageCache() => SignImageService.instance.clearCache();
}
