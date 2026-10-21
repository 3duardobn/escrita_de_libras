import 'package:diacritic/diacritic.dart';

final _nonAlphanumeric = RegExp(r'[^a-z0-9]+');
final _whitespace = RegExp(r'\s+');

/// Normalização idêntica à de `tools/signpuddle/normalize.py`.
///
/// Minúsculas, sem acentos, `@` vira `o`, pontuação vira espaço e espaços
/// repetidos são colapsados. É essa forma que o banco guarda em `term_norm`.
String normalizeForSearch(Object? value) {
  if (value == null) return '';
  final text = removeDiacritics(value.toString())
      .toLowerCase()
      .replaceAll('@', 'o')
      .replaceAll(_nonAlphanumeric, ' ')
      .replaceAll(_whitespace, ' ')
      .trim();
  return text;
}

/// Divide a entrada manual de termos por vírgula, ponto e vírgula ou linha.
List<String> splitTerms(String value) {
  return value
      .split(RegExp(r'[,;\n]'))
      .map((term) => term.trim())
      .where((term) => term.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

/// Monta a consulta FTS5 (prefixo por token, todos os tokens em AND).
String ftsQueryFor(String normalized) {
  final tokens = normalized
      .split(' ')
      .where((token) => token.isNotEmpty)
      .map((token) => '"${token.replaceAll('"', '""')}"*')
      .toList(growable: false);
  return tokens.join(' ');
}

/// Primeiros termos que começam com o texto digitado, para autocomplete.
List<String> filterSuggestions(
  List<String> terms,
  String query, {
  int limit = 6,
}) {
  final normalized = normalizeForSearch(query);
  if (normalized.length < 2) return const [];
  final matches = <String>[];
  for (final term in terms) {
    if (normalizeForSearch(term).startsWith(normalized)) {
      matches.add(term);
      if (matches.length >= limit) break;
    }
  }
  return matches;
}
