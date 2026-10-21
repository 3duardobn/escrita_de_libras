import 'package:flutter_test/flutter_test.dart';

import 'package:escrita_de_libras/core/text_normalizer.dart';

void main() {
  group('normalizeForSearch', () {
    test('remove acentos, caixa e pontuação', () {
      expect(normalizeForSearch('Água'), 'agua');
      expect(normalizeForSearch('  Queda-d\'água (1) '), 'queda d agua 1');
      expect(normalizeForSearch('AÇÃO'), 'acao');
      expect(normalizeForSearch('casa@'), 'casao');
      expect(normalizeForSearch('ser  humano'), 'ser humano');
      expect(normalizeForSearch(null), '');
    });

    test('mantém a mesma regra usada pelo Python', () {
      expect(normalizeForSearch('PÃO-de-AÇÚCAR'), 'pao de acucar');
    });
  });

  group('splitTerms', () {
    test('separa por vírgula, ponto e vírgula e linha', () {
      expect(
        splitTerms('casa, moradia; lar\nabrigo, casa'),
        ['casa', 'moradia', 'lar', 'abrigo'],
      );
    });
  });

  group('ftsQueryFor', () {
    test('cria prefixos por token', () {
      expect(ftsQueryFor('casa de banho'), '"casa"* "de"* "banho"*');
      expect(ftsQueryFor(''), '');
    });
  });

  group('filterSuggestions', () {
    test('filtra por prefixo normalizado e limita', () {
      final terms = ['água', 'aguardar', 'casa', 'Aguaceiro'];
      expect(filterSuggestions(terms, 'agu', limit: 2), [
        'água',
        'aguardar',
      ]);
      expect(filterSuggestions(terms, 'a'), isEmpty);
    });
  });
}
