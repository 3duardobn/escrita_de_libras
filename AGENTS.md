# AGENTS.md — Escrita de Libras

App Flutter (Dart 3) + ferramentas Python que pesquisa sinais de Libras num
SQLite local e desenha o SignWriting nativamente via fontes TrueType oficiais.

## Como funciona

- `assets/signpuddle.db` é o banco base, **somente leitura**, gerado por
  `tools/signpuddle/build_sqlite.py`. Ele é copiado do asset para o
  armazenamento do app na primeira execução.
- O banco do usuário (`user_data.db`) é **separado** e gravável: anotações,
  favoritos, sinais manuais e buscas recentes. Uma atualização do banco base
  nunca apaga dados do usuário.
- **Renderização Nativa**: O app renderiza o SignWriting diretamente no Canvas
  via `CustomPainter` (`lib/ui/widgets/sign_writing_canvas.dart`) usando as
  fontes `SuttonSignWritingLine.ttf` e `SuttonSignWritingFill.ttf` em
  `assets/fonts/`. O código SWU/FSW é decodificado localmente por
  `lib/core/swu_parser.dart`.
- **Fallback para SVG/Rede**: Apenas caso o sinal não contenha código visual
  SWU/FSW diretamente parseável, o app recorre ao `SignImageService`
  (memória → blob no banco → arquivo em cache → rede).

## Comandos

```bash
flutter pub get
flutter analyze
flutter test

# dados (re)gerados
python -m tools.signpuddle.sync
python -m tools.signpuddle.download_images --all --into-db   # offline opcional

# testes Python
python -m unittest discover -s tools/signpuddle/tests -v
```

## Regras importantes

- **Exclusividade para Libras**: O projeto é estritamente limitado ao
  dicionário de Libras (`bzs-BR-dictionary-public`). Nenhuma outra língua de
  sinais deve ser misturada nos scrapes ou banco base.
- **Normalização**: `lib/core/text_normalizer.dart` e
  `tools/signpuddle/normalize.py` implementam a MESMA regra (NFKD sem acentos,
  minúsculas, `@`→`o`, não-alfanumérico→espaço, colapsar espaços). O banco
  guarda `term_norm`; o app normaliza a consulta antes de comparar. Alterou
  uma, altere a outra e rode os testes dos dois lados.
- **Não apague dados do usuário** ao trocar a versão do `signpuddle.db`.
- Web não tem SQLite local: mantenha os guardas `kIsWeb` e a tela de
  "use Android/Linux".
- O banco base é aberto em modo `readOnly: true`.
- Ao mexer no esquema do banco base, suba `SCHEMA_VERSION` em
  `tools/signpuddle/config.py` **e** `AppInfo.databaseVersion` em
  `lib/core/app_info.dart` (os dois devem casar com o `PRAGMA user_version`).

## Estrutura dos dados do SignPuddle

O JSON tem `data` (lista de entradas). Cada entrada: `id`, `sign` (SWU
Unicode), `terms` (lista), `text`, `signtext`, `source`, `detail` (pode ter
`video`), `user`, `created_at`, `updated_at`. Quando `sign` é vazio, usa-se
`signtext` e marca-se `is_signtext=1`.
