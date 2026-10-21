import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:escrita_de_libras/core/swu_parser.dart';
import 'package:escrita_de_libras/ui/widgets/sign_writing_canvas.dart';

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
}
