import 'dart:math' as math;

/// Representa um símbolo posicionado dentro de um sinal em SignWriting.
class SwuSpatial {
  const SwuSpatial({
    required this.symbolId,
    required this.x,
    required this.y,
    required this.lineChar,
    required this.fillChar,
  });

  /// Identificador numérico do símbolo ISWA 2010 (1 .. 37811+).
  final int symbolId;

  /// Coordenada horizontal (em pontos na grade SignWriting, normalmente 250..749).
  final int x;

  /// Coordenada vertical (em pontos na grade SignWriting, normalmente 250..749).
  final int y;

  /// Caractere mapeado no Plano 15 (0xF0000 + symbolId) para a fonte SuttonSignWritingLine.
  final String lineChar;

  /// Caractere mapeado no Plano 16 (0x100000 + symbolId) para a fonte SuttonSignWritingFill.
  final String fillChar;
}

/// Layout espacial completo de um sinal decodificado.
class SwuSignLayout {
  const SwuSignLayout({
    required this.raw,
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
    required this.spatials,
  });

  final String raw;
  final int minX;
  final int minY;
  final int maxX;
  final int maxY;
  final List<SwuSpatial> spatials;

  int get width => math.max(1, maxX - minX);
  int get height => math.max(1, maxY - minY);
  bool get isEmpty => spatials.isEmpty;
}

/// Parser para SignWriting em Unicode (SWU) e Formal SignWriting em ASCII (FSW).
class SwuParser {
  const SwuParser._();

  static const int _boxMin = 0x1D801; // 𝠁 (B)
  static const int _boxMax = 0x1D804; // 𝠄 (R)
  static const int _coordBase = 0x1D80C;
  static const int _symbolMin = 0x40001;
  static const int _symbolMax = 0x4F480;

  static final RegExp _fswPattern = RegExp(
    r'([BLMR])(\d{3})x(\d{3})((?:S[0-9a-f]{5}\d{3}x\d{3})*)',
  );

  static final RegExp _fswSpatialPattern = RegExp(
    r'S([0-9a-f]{3})([0-9a-f])([0-9a-f])(\d{3})x(\d{3})',
  );

  /// Converte código SWU ou FSW em um layout pronto para renderização.
  static SwuSignLayout? parse(String? raw) {
    if (raw == null) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;

    // 1. Tentar parsear como SWU (formato do SQLite)
    final swuLayout = _parseSwu(text);
    if (swuLayout != null && swuLayout.spatials.isNotEmpty) {
      return swuLayout;
    }

    // 2. Tentar parsear como FSW (formato ASCII / entrada manual)
    final fswLayout = _parseFsw(text);
    if (fswLayout != null && fswLayout.spatials.isNotEmpty) {
      return fswLayout;
    }

    return null;
  }

  static SwuSignLayout? _parseSwu(String text) {
    final runes = text.runes.toList(growable: false);
    if (runes.isEmpty) return null;

    // Encontra o marcador de signbox (𝠁..𝠄)
    var boxIndex = -1;
    for (var i = 0; i < runes.length; i++) {
      final r = runes[i];
      if (r >= _boxMin && r <= _boxMax) {
        boxIndex = i;
        break;
      }
    }

    int rawMaxX = 500;
    int rawMaxY = 500;
    var spatialsStart = 0;

    if (boxIndex != -1 && boxIndex + 2 < runes.length) {
      rawMaxX = _swuCoord(runes[boxIndex + 1]);
      rawMaxY = _swuCoord(runes[boxIndex + 2]);
      spatialsStart = boxIndex + 3;
    }

    final spatials = <SwuSpatial>[];
    var i = spatialsStart;
    while (i < runes.length) {
      final r = runes[i];
      // Verifica se é um símbolo ISWA 2010
      if (r >= _symbolMin && r <= _symbolMax) {
        if (i + 2 < runes.length) {
          final x = _swuCoord(runes[i + 1]);
          final y = _swuCoord(runes[i + 2]);
          final id = r - 0x40000;
          spatials.add(
            SwuSpatial(
              symbolId: id,
              x: x,
              y: y,
              lineChar: String.fromCharCode(0xF0000 + id),
              fillChar: String.fromCharCode(0x100000 + id),
            ),
          );
          i += 3;
          continue;
        }
      }
      i++;
    }

    if (spatials.isEmpty) return null;

    var minX = spatials.first.x;
    var minY = spatials.first.y;
    var maxX = rawMaxX;
    var maxY = rawMaxY;

    for (final s in spatials) {
      if (s.x < minX) minX = s.x;
      if (s.y < minY) minY = s.y;
      // Garante margem para o tamanho do glifo (base ~30px)
      if (s.x + 30 > maxX) maxX = s.x + 30;
      if (s.y + 30 > maxY) maxY = s.y + 30;
    }

    return SwuSignLayout(
      raw: text,
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
      spatials: spatials,
    );
  }

  static SwuSignLayout? _parseFsw(String text) {
    final match = _fswPattern.firstMatch(text);
    if (match == null) return null;

    final rawMaxX = int.tryParse(match.group(2) ?? '') ?? 500;
    final rawMaxY = int.tryParse(match.group(3) ?? '') ?? 500;
    final spatialsPart = match.group(4) ?? '';

    final spatials = <SwuSpatial>[];
    for (final sm in _fswSpatialPattern.allMatches(spatialsPart)) {
      final k1 = sm.group(1)!;
      final k2 = sm.group(2)!;
      final k3 = sm.group(3)!;
      final x = int.tryParse(sm.group(4)!) ?? 500;
      final y = int.tryParse(sm.group(5)!) ?? 500;

      final p1 = int.parse(k1, radix: 16);
      final p2 = int.parse(k2, radix: 16);
      final p3 = int.parse(k3, radix: 16);
      final id = 1 + (p1 - 256) * 96 + p2 * 16 + p3;

      spatials.add(
        SwuSpatial(
          symbolId: id,
          x: x,
          y: y,
          lineChar: String.fromCharCode(0xF0000 + id),
          fillChar: String.fromCharCode(0x100000 + id),
        ),
      );
    }

    if (spatials.isEmpty) return null;

    var minX = spatials.first.x;
    var minY = spatials.first.y;
    var maxX = rawMaxX;
    var maxY = rawMaxY;

    for (final s in spatials) {
      if (s.x < minX) minX = s.x;
      if (s.y < minY) minY = s.y;
      if (s.x + 30 > maxX) maxX = s.x + 30;
      if (s.y + 30 > maxY) maxY = s.y + 30;
    }

    return SwuSignLayout(
      raw: text,
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
      spatials: spatials,
    );
  }

  static int _swuCoord(int rune) => rune - _coordBase + 250;
}
