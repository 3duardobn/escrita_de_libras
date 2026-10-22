import 'package:flutter_test/flutter_test.dart';
import 'package:escrita_de_libras/core/swu_parser.dart';

void main() {
  group('SwuParser', () {
    test('parseia SWU real de "rato" do banco', () {
      // Entrada real do banco SQLite para o sinal 1 ("rato")
      const swuRato =
          '𝠀\u{4c005}\u{40ce1}\u{46241}\u{46901}𝠃𝤘𝤧\u{4c005}𝣴𝣵\u{461e1}𝤀𝤜\u{40ce1}𝣢𝤋\u{46c75}𝣒𝤀';

      final layout = SwuParser.parse(swuRato);
      expect(layout, isNotNull);
      expect(layout!.wordCount, 1);
      expect(layout.isMultiSign, isFalse);
      expect(layout.spatials.length, 4);

      // Símbolo 1: 0x4c005 -> id: 0xc005 = 49157 em (482, 483)
      final s1 = layout.spatials[0];
      expect(s1.symbolId, 0x4c005 - 0x40000);
      expect(s1.x, 482);
      expect(s1.y, 483);
      expect(s1.lineChar.runes.first, 0xFC005);
      expect(s1.fillChar.runes.first, 0x10C005);

      // Símbolo 2: em (494, 522)
      final s2 = layout.spatials[1];
      expect(s2.x, 494);
      expect(s2.y, 522);

      // Símbolo 3: em (464, 505)
      final s3 = layout.spatials[2];
      expect(s3.x, 464);
      expect(s3.y, 505);

      // Símbolo 4: em (448, 494)
      final s4 = layout.spatials[3];
      expect(s4.x, 448);
      expect(s4.y, 494);

      expect(layout.minX, 448);
      expect(layout.minY, 483);
      expect(layout.width, greaterThanOrEqualTo(70));
      expect(layout.height, greaterThanOrEqualTo(50));
    });

    test('parseia frase composta com múltiplos sinais em coluna vertical (SignText de "brasil")', () {
      // Entrada real do banco SQLite para o sinal 22290 ("brasil"), que contém 5 palavras
      const swuBrasilFrase =
          '𝠃𝥀𝤩\u{4005a}𝣩𝣤\u{40052}𝤈𝣤\u{47715}𝤩𝣯\u{476e3}𝤞𝤎\u{461e1}𝤂𝤝\u{476fb}𝣍𝤍\u{47717}𝣍𝣯 '
          '𝠃𝤺𝤲\u{40052}𝤉𝣛\u{4005a}𝣧𝣜\u{47024}𝤐𝤏\u{47714}𝤤𝣲\u{47036}𝣥𝤐\u{4771c}𝣓𝣲\u{461e1}𝤁𝤧 '
          '𝠃𝤵𝤲\u{40052}𝤉𝣚\u{4005a}𝣦𝣚\u{4942d}𝤡𝣴\u{49435}𝣘𝣶\u{461e1}𝤁𝤧 '
          '𝠃𝤱𝤑\u{459c1}𝣜𝤂\u{4942b}𝤅𝣻 '
          '𝠃𝤫𝤯\u{45951}𝤇𝣫\u{45b99}𝣥𝣸\u{46c75}𝤑𝣟\u{46c75}𝣡𝣝\u{4b5a3}𝣴𝤒';

      final layout = SwuParser.parse(swuBrasilFrase);
      expect(layout, isNotNull);
      expect(layout!.wordCount, 5);
      expect(layout.isMultiSign, isTrue);
      expect(layout.spatials.length, 26);

      // Sinais organizados em coluna vertical canônica (top-to-bottom)
      expect(layout.height, greaterThan(400));
      expect(layout.width, lessThan(160));

      // O último símbolo da última palavra está verticalmente abaixo do primeiro
      final firstY = layout.spatials.first.y;
      final lastY = layout.spatials.last.y;
      expect(lastY, greaterThan(firstY + 300));
    });

    test('swuToFsw converte SWU para FSW ASCII legível sem caracteres especiais/quadrados', () {
      const swuRato = '𝠀񌀅񀳡񆉁񆤁𝠃𝤘𝤧񌀅𝣴𝣵񆇡𝤀𝤜񀳡𝣢𝤋񆱵𝣒𝤀';
      final fsw = SwuParser.swuToFsw(swuRato);
      expect(fsw, isNotEmpty);
      expect(fsw.startsWith('M518x533'), isTrue);
      expect(fsw.contains('S30004482x483'), isTrue);
      // Garantir que é puramente ASCII (sem caracteres que causem "tofu" / quadrados)
      expect(RegExp(r'^[\x20-\x7E]+$').hasMatch(fsw), isTrue);
    });

    test('parseia FSW em formato ASCII', () {
      const fsw =
          'M525x535S2e748483x510S10011501x466S2e704510x500S10019476x475';

      final layout = SwuParser.parse(fsw);
      expect(layout, isNotNull);
      expect(layout!.spatials.length, 4);

      expect(layout.spatials[0].x, 483);
      expect(layout.spatials[0].y, 510);
      expect(layout.spatials[0].symbolId, 46825);

      expect(layout.spatials[1].x, 501);
      expect(layout.spatials[1].y, 466);

      expect(layout.spatials[2].x, 510);
      expect(layout.spatials[2].y, 500);

      expect(layout.spatials[3].x, 476);
      expect(layout.spatials[3].y, 475);
    });

    test('retorna null para entradas nulas ou inválidas', () {
      expect(SwuParser.parse(null), isNull);
      expect(SwuParser.parse(''), isNull);
      expect(SwuParser.parse('   '), isNull);
      expect(SwuParser.parse('texto qualquer sem signwriting'), isNull);
    });
  });
}
