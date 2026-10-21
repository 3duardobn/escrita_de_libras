import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:escrita_de_libras/app.dart';
import 'package:escrita_de_libras/ui/theme.dart';
import 'package:escrita_de_libras/ui/widgets/section_card.dart';

void main() {
  testWidgets('mostra a tela de carregamento enquanto o estado inicia', (
    tester,
  ) async {
    await tester.pumpWidget(const EscritaDeLibrasApp());
    await tester.pump();

    expect(find.text('Escrita de Libras'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('SignTermChips limita os termos e mostra o restante', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SignTermChips(terms: ['água', 'water', 'líquido'], max: 2),
        ),
      ),
    );

    expect(find.text('água'), findsOneWidget);
    expect(find.text('water'), findsOneWidget);
    expect(find.text('líquido'), findsNothing);
    expect(find.text('+1'), findsOneWidget);
  });
}
