import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/base_database.dart';
import '../data/models.dart';

class SignImageException implements Exception {
  SignImageException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Baixa, guarda em cache e serve os SVGs do SignPuddle.
///
/// Ordem de busca: memória → blob embutido no SQLite (quando o usuário rodou
/// o downloader com `--into-db`) → arquivo em cache → rede.
class SignImageService {
  SignImageService({http.Client? client}) : _client = client ?? http.Client();

  /// Instância global. Pode ser substituída em testes para injetar um cliente.
  static SignImageService instance = SignImageService();

  final http.Client _client;
  final LinkedHashMap<String, Uint8List> _memory = LinkedHashMap();
  final Map<String, Future<Uint8List?>> _pending = {};
  static const int _memoryLimit = 160;

  Directory? _cacheDir;

  Future<Directory?> _cacheDirectory() async {
    if (kIsWeb) return null;
    if (_cacheDir != null) return _cacheDir;
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory(p.join(support.path, 'signpuddle', 'images'));
      await dir.create(recursive: true);
      _cacheDir = dir;
      return dir;
    } catch (_) {
      return null;
    }
  }

  String _cacheKey(SignEntry entry) =>
      entry.key.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');

  Future<Uint8List?> load(
    SignEntry entry, {
    bool force = false,
    bool useBlob = true,
  }) {
    if (!entry.hasImage) return Future.value(null);
    final key = _cacheKey(entry);
    if (!force) {
      final memory = _memory.remove(key);
      if (memory != null) {
        _memory[key] = memory;
        return Future.value(memory);
      }
      final pending = _pending[key];
      if (pending != null) return pending;
    }

    final future = _load(entry, key, force: force, useBlob: useBlob);
    _pending[key] = future;
    return future.whenComplete(() => _pending.remove(key));
  }

  Future<Uint8List?> _load(
    SignEntry entry,
    String key, {
    required bool force,
    required bool useBlob,
  }) async {
    if (!force && useBlob && entry.sourceId != null) {
      try {
        final blob = await BaseDatabase.instance.imageBlob(entry.sourceId!);
        if (blob != null && blob.isNotEmpty) {
          _remember(key, blob);
          return blob;
        }
      } catch (_) {
        // Sem tabela de imagens ou blob corrompido: segue para o cache/rede.
      }
    }

    final dir = await _cacheDirectory();
    final file = dir == null ? null : File(p.join(dir.path, '$key.svg'));
    if (!force && file != null && await file.exists()) {
      try {
        final bytes = await file.readAsBytes();
        if (_looksLikeSvg(bytes)) {
          _remember(key, bytes);
          return bytes;
        }
      } catch (_) {
        // Arquivo parcial: tenta baixar de novo.
      }
    }

    try {
      final response = await _client
          .get(
            Uri.parse(entry.imageUrl),
            headers: const {
              'User-Agent': 'EscritaDeLibras/1.0 (Flutter; educacional)',
              'Accept': 'image/svg+xml',
            },
          )
          .timeout(const Duration(seconds: 35));
      if (response.statusCode != 200) {
        throw SignImageException(
          'O SignPuddle respondeu ${response.statusCode}.',
        );
      }
      if (!_looksLikeSvg(response.bodyBytes)) {
        throw SignImageException('A resposta não é um SVG válido.');
      }
      _remember(key, response.bodyBytes);
      if (file != null) {
        try {
          final tmp = File('${file.path}.tmp');
          await tmp.writeAsBytes(response.bodyBytes, flush: true);
          await tmp.rename(file.path);
        } catch (_) {
          // Cache em disco é opcional; a imagem já está na memória.
        }
      }
      return response.bodyBytes;
    } on TimeoutException {
      throw SignImageException('Tempo esgotado ao buscar o sinal.');
    } on http.ClientException catch (error) {
      throw SignImageException('Falha de rede: ${error.message}');
    }
  }

  bool _looksLikeSvg(Uint8List bytes) {
    final start = String.fromCharCodes(bytes.take(200)).trimLeft();
    return start.startsWith('<svg') || start.startsWith('<?xml');
  }

  void _remember(String key, Uint8List bytes) {
    _memory.remove(key);
    _memory[key] = bytes;
    while (_memory.length > _memoryLimit) {
      _memory.remove(_memory.keys.first);
    }
  }

  Future<void> clearCache() async {
    _memory.clear();
    final dir = await _cacheDirectory();
    if (dir != null && await dir.exists()) {
      await dir.delete(recursive: true);
      await dir.create(recursive: true);
      _cacheDir = dir;
    }
  }

  Future<int> cacheSizeBytes() async {
    final dir = await _cacheDirectory();
    if (dir == null || !await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }
}
