import 'dart:convert';

import '../core/sign_image_url.dart';

enum SignKind { swu, fsw }

/// Um sinal do dicionário base ou criado manualmente pelo usuário.
class SignEntry {
  const SignEntry({
    required this.key,
    required this.title,
    required this.terms,
    required this.sign,
    this.signKind = SignKind.swu,
    this.sourceId,
    this.customId,
    this.source,
    this.description,
    this.signtext,
    this.fromSigntext = false,
    this.userName,
    this.createdAt,
    this.updatedAt,
    this.detail = const {},
    this.customNote,
  });

  final String key;
  final String title;
  final List<String> terms;
  final String sign;
  final SignKind signKind;
  final int? sourceId;
  final String? customId;
  final String? source;
  final String? description;
  final String? signtext;
  final bool fromSigntext;
  final String? userName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> detail;
  final String? customNote;

  bool get isCustom => customId != null;
  bool get hasImage => sign.trim().isNotEmpty;

  String get imageUrl => signPuddleSvgUrl(sign, signKind);

  String? get entryUrl => sourceId == null ? null : signPuddleEntryUrl(sourceId!);

  String get sourceLabel {
    final value = source?.trim();
    return (value == null || value.isEmpty) ? 'SignPuddle' : value;
  }

  String get shortId => sourceId?.toString() ?? customId ?? '';

  /// Extrai um link de vídeo do campo `detail` do SignPuddle.
  String? get videoUrl {
    final raw = detail['video'];
    if (raw is! String || raw.trim().isEmpty) return null;
    final value = raw.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final match = RegExp(
      r'''(?:src|href)\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(value);
    return match?.group(1);
  }

  SignEntry copyWith({
    String? title,
    List<String>? terms,
    String? source,
    String? description,
    String? customNote,
    DateTime? updatedAt,
  }) {
    return SignEntry(
      key: key,
      title: title ?? this.title,
      terms: terms ?? this.terms,
      sign: sign,
      signKind: signKind,
      sourceId: sourceId,
      customId: customId,
      source: source ?? this.source,
      description: description ?? this.description,
      signtext: signtext,
      fromSigntext: fromSigntext,
      userName: userName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      detail: detail,
      customNote: customNote ?? this.customNote,
    );
  }

  factory SignEntry.fromBaseRow(
    Map<String, Object?> row, {
    List<String> terms = const [],
  }) {
    final detail = <String, dynamic>{};
    final rawDetail = row['detail_json'] as String?;
    if (rawDetail != null && rawDetail.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawDetail);
        if (decoded is Map) detail.addAll(decoded.cast<String, dynamic>());
      } catch (_) {
        // Metadado corrompido não deve impedir a exibição do sinal.
      }
    }
    final id = row['id'] as int;
    final title = (row['title'] as String?)?.trim();
    final list = terms.isNotEmpty
        ? terms
        : (title != null && title.isNotEmpty ? <String>[title] : <String>[]);
    return SignEntry(
      key: 'base:$id',
      sourceId: id,
      title: (title == null || title.isEmpty) ? 'Sem título' : title,
      terms: list,
      sign: (row['swu'] as String?) ?? '',
      fromSigntext: (row['is_signtext'] as int? ?? 0) == 1,
      source: row['source'] as String?,
      description: row['description'] as String?,
      signtext: row['signtext'] as String?,
      userName: row['user'] as String?,
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
      detail: detail,
    );
  }

  factory SignEntry.fromCustomRow(Map<String, Object?> row) {
    final id = row['id'] as String;
    final terms = _decodeTerms(row['terms'] as String?);
    final title = (row['title'] as String?)?.trim();
    return SignEntry(
      key: 'custom:$id',
      customId: id,
      title: (title == null || title.isEmpty)
          ? (terms.isNotEmpty ? terms.first : 'Sem título')
          : title,
      terms: terms,
      sign: (row['sign'] as String?) ?? '',
      signKind: (row['sign_kind'] as String?) == 'fsw'
          ? SignKind.fsw
          : SignKind.swu,
      source: row['source'] as String?,
      description: row['note'] as String?,
      customNote: row['note'] as String?,
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
    );
  }

  static List<String> _decodeTerms(String? encoded) {
    if (encoded == null || encoded.isEmpty) return const [];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList(growable: false);
      }
    } catch (_) {}
    return const [];
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

/// Metadados pessoais que o usuário adiciona a um sinal do dicionário base.
class SignNote {
  const SignNote({
    required this.signKey,
    this.customTitle = '',
    this.terms = const [],
    this.tags = const [],
    this.note = '',
    this.updatedAt,
  });

  final String signKey;
  final String customTitle;
  final List<String> terms;
  final List<String> tags;
  final String note;
  final DateTime? updatedAt;

  bool get isEmpty =>
      customTitle.trim().isEmpty &&
      terms.isEmpty &&
      tags.isEmpty &&
      note.trim().isEmpty;

  factory SignNote.fromRow(Map<String, Object?> row) {
    return SignNote(
      signKey: row['sign_key'] as String,
      customTitle: (row['custom_title'] as String?) ?? '',
      terms: SignEntry._decodeTerms(row['custom_terms'] as String?),
      tags: SignEntry._decodeTerms(row['tags'] as String?),
      note: (row['note'] as String?) ?? '',
      updatedAt: SignEntry._parseDate(row['updated_at']),
    );
  }
}
