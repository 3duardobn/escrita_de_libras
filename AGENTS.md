# AGENTS.md — Escrita de Libras

App Flutter (Dart 3) + ferramentas Python que pesquisa sinais de Libras num
SQLite local e desenha o SignWriting via SignPuddle 3.

## Como funciona

- `assets/signpuddle.db` é o banco base, **somente leitura**, gerado por
  `tools/signpuddle/build_sqlite.py`. Ele é copiado do asset para o
  armazenamento do app na primeira execução.
- O banco do usuário (`user_data.db`) é **separado** e gravável: anotações,
  favoritos, sinais manuais e buscas recentes. Uma atualização do banco base
  nunca apaga dados do usuário.
- A imagem de cada sinal é um SVG servido por
  `https://signpuddle.com/server/{swu|fsw}/svg/{código}`. O app usa memória →
  blob (se `sign_images` existir) → arquivo em cache → rede.

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
