import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:escrita_de_libras/core/swu_parser.dart';
import 'package:escrita_de_libras/data/models.dart';
import 'package:escrita_de_libras/ui/widgets/sign_writing_canvas.dart';
import 'package:escrita_de_libras/ui/widgets/sign_writing_image.dart';

void main() {
  testWidgets('SignWritingCanvas renderiza sinal sem erros', (tester) async {
    const swuRato =
        '𝠀\u{4c005}\u{40ce1}\u{46241}\u{46901}𝠃𝤘𝤧\u{4c005}𝣴𝣵\u{461e1}𝤀𝤜\u{40ce1}𝣢𝤋\u{46c75}𝣒𝤀';
    final layout = SwuParser.parse(swuRato);
    expect(layout, isNotNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 200,
            child: SignWritingCanvas(layout: layout!),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(SignWritingCanvas), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('SignWritingImage ativa rolagem horizontal para frases compostas', (tester) async {
    const swuBrasilFrase =
        '𝠃𝥀𝤩\u{4005a}𝣩𝣤\u{40052}𝤈𝣤\u{47715}𝤩𝣯\u{476e3}𝤞𝤎\u{461e1}𝤂𝤝\u{476fb}𝣍𝤍\u{47717}𝣍𝣯 '
        '𝠃𝤺𝤲\u{40052}𝤉𝣛\u{4005a}𝣧𝣜\u{47024}𝤐𝤏\u{47714}𝤤𝣲\u{47036}𝣥𝤐\u{4771c}𝣓𝣲\u{461e1}𝤁𝤧 '
        '𝠃𝤵𝤲\u{40052}𝤉𝣚\u{4005a}𝣦𝣚\u{4942d}𝤡𝣴\u{49435}𝣘𝣶\u{461e1}𝤁𝤧 '
        '𝠃𝤱𝤑\u{459c1}𝣜𝤂\u{4942b}𝤅𝣻 '
        '𝠃𝤫𝤯\u{45951}𝤇𝣫\u{45b99}𝣥𝣸\u{46c75}𝤑𝣟\u{46c75}𝣡𝣝\u{4b5a3}𝣴𝤒';

    const entry = SignEntry(
      key: 'base:22290',
      title: 'brasil',
      terms: ['brasil'],
      sign: swuBrasilFrase,
      fromSigntext: true,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 148,
            child: SignWritingImage(entry: entry),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(SignWritingImage), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('5 sinais'), findsOneWidget);
  });
}
