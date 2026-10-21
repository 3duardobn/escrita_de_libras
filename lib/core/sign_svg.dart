import 'dart:convert';
import 'dart:typed_data';

/// O SignPuddle gera SVGs com `<svg x="..." y="...">` aninhados (um por
/// símbolo). O `flutter_svg` não suporta `<svg>` aninhado. Aqui convertemos
/// cada bloco aninhado em um `<g transform="translate(x y)">`, mantendo a
/// geometria, e removemos o `<text>` de metadados (`font-size="0"`).
///
/// Exemplo:
/// ```xml
///   <svg version="1.1" viewBox="434 429 129 208"> ...
///     <svg x="445" y="457"><g transform="..."><path .../></g></svg>
///   </svg>
/// ```
/// vira:
/// ```xml
///   <svg version="1.1" viewBox="434 429 129 208"> ...
///     <g transform="translate(445 457)"><g transform="..."><path .../></g></g>
///   </svg>
/// ```
final _nestedSvg = RegExp(
  r'<svg\s+x="([^"]+)"\s+y="([^"]+)"[^>]*>(.*?)</svg>',
  dotAll: true,
);
final _metadataText = RegExp(r'<text[^>]*>.*?</text>', dotAll: true);

/// Normaliza um SVG do SignPuddle para algo que o `flutter_svg` consiga ler.
Uint8List normalizeSignPuddleSvg(Uint8List bytes) {
  var text = utf8.decode(bytes, allowMalformed: true);
  text = text.replaceAll(_metadataText, '');
  text = text.replaceAllMapped(_nestedSvg, (match) {
    final x = match[1]!;
    final y = match[2]!;
    final inner = match[3]!;
    return '<g transform="translate($x $y)">$inner</g>';
  });
  return Uint8List.fromList(utf8.encode(text));
}
