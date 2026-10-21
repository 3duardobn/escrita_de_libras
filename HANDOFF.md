# Handoff — Escrita de Libras

> Estado atual do projeto, o que já foi feito, o que falta e como continuar.
> Atualizado em 21/10/2026. Repositório: `/home/eduardo/projetos/personal/libras/escrita_de_libras`
> Repositório Git inicializado e renderização nativa por fontes implementada.

---

## 1. O que é o projeto

App **Flutter** + ferramentas **Python** que pesquisa sinais de **Libras** num
SQLite local e desenha o **SignWriting** (SVG) buscado do **SignPuddle 3**.

Pedido original do usuário: "um projeto no estilo de `libras_dicionario`, só que
retorna os sinais do site signbank.org/signpuddle, mesma lógica de imagem,
script python para copiar, a palavra fica num SQLite, o signwriting é um pull no
site, e também salvar metadados do sinal e gerar manualmente."

Decisão central: usar a **API pública do SignPuddle 3** (não a UI antiga do
SignPuddle 2 em signbank.org):

- Dicionário: `bzs-BR-dictionary-public` (Libras / ISO `bzs`).
- JSON: `https://signpuddle.com/server/dictionary/bzs-BR-dictionary-public.json`
- SVG: `https://signpuddle.com/server/swu/svg/{SWU}` (ou `/fsw/svg/{FSW}`).
- API tem CORS (`Access-Control-Allow-Origin: *`).

---

## 2. Estado do banco (dados)

Gerado e commitado em `assets/signpuddle.db` (≈10 MB), com:

- **25.611** sinais, **39.802** termos, **3.601** descrições, **284** vídeos.
- **25.580** sinais com desenho (SWU/FSW); **31** sem desenho nenhum.
- **1.312** entradas com `sign` vazio; **1.281** têm `signtext` utilizável
  → regra: `swu = sign se não vazio, senão signtext`, com `is_signtext=1`.

Esquema (criado por `tools/signpuddle/build_sqlite.py`):

- `meta(key, value)` — dicionário, `built_at`, contagens, `schema_version`.
- `signs(id, title, swu, is_signtext, source, description, signtext,
  detail_json, user, created_at, updated_at)`.
- `terms(sign_id, term, term_norm, position, is_title)` + índice em `term_norm`.
- `terms_fts` (FTS5, external content em `terms`, tokenizer
  `unicode61 remove_diacritics 2`).
- `sign_images(sign_id, svg)` — **opcional**, criado só quando se roda
  `download_images.py --into-db`.

Normalização (deve casar Python ↔ Dart): NFKD sem acentos, minúsculas, `@`→`o`,
não-alfanumérico→espaço, colapsar espaços.

---

## 3. Estrutura de arquivos

```
lib/
  main.dart                          entrypoint + init desktop FFI
  app.dart                           MaterialApp, splash, tela de erro/web
  core/
    app_info.dart                    nome, dicionário, versões, URLs
    text_normalizer.dart             normalizeForSearch, splitTerms, ftsQueryFor
    sign_image_url.dart              URL do SVG e URL da entrada no SignPuddle
    sign_svg.dart                    *** normaliza SVG aninhado do SignPuddle ***
    format.dart                      formatCount/formatDate/formatBytes
  data/
    models.dart                      SignEntry, SignNote, SignKind
    base_database.dart               SQLite base (read-only) + busca
    user_database.dart               anotações/favoritos/custom/recentes
    dictionary_repository.dart       junta base + usuário
  services/
    sign_image_service.dart          cache memória→blob→arquivo→rede
  state/
    app_state.dart                   ChangeNotifier global
  platform/
    sqflite_platform.dart            stub web
    sqflite_platform_io.dart         sqfliteFfiInit no Linux/Windows
  ui/
    theme.dart                       Material 3, claro/escuro
    home_screen.dart                 busca, sugestões, resultados, boas-vindas
    sign_detail_screen.dart          detalhe, metadados, favoritar, copiar
    favorites_screen.dart            lista de favoritos
    settings_screen.dart             dados, cache, export/import, tema, sobre
    custom_sign_screen.dart          criar/editar sinal manual (SWU/FSW)
    widgets/
      sign_writing_image.dart        moldura branca + SVG (usa sign_svg.dart)
      sign_card.dart                 card da lista
      section_card.dart              SectionCard, InfoRow, EmptyState, SignTermChips
      note_editor_sheet.dart         editor de metadados (bottom sheet)

tools/signpuddle/
  config.py, normalize.py, signpuddle_api.py, fetch_dictionary.py,
  build_sqlite.py, download_images.py, sync.py, list_dictionaries.py,
  requirements.txt
  tests/test_normalize.py, tests/test_build_sqlite.py

assets/
  signpuddle.db       (banco gerado, asset do app)
  sample_sign.svg     (exemplo "água" — já achatado; ver seção 5)

test/
  text_normalizer_test.dart
  base_database_test.dart
  user_database_test.dart
  full_database_test.dart
  home_screen_test.dart     (criado; ver pendências)
  widget_test.dart
```

Também: `README.md`, `AGENTS.md`, `LICENSE` (GPL-3.0, copiada do projeto de
referência), `.gitignore` (inclui `tools/signpuddle/data/`), ícones Android/web
gerados.

---

## 4. O que JÁ está feito e funcionando

1. **Tooling Python** (tudo testado):
   - `python -m tools.signpuddle.sync` → baixa o JSON (≈20 MB) e gera o SQLite.
   - `list_dictionaries`, `fetch_dictionary`, `build_sqlite`, `download_images`.
   - Testes Python passando (7 testes via `unittest`).

2. **App Flutter**:
   - `flutter analyze` → **No issues found** (antes da última mudança de SVG).
   - `flutter test` → **21 testes passando** (antes da última mudança de SVG).
   - `flutter build apk --debug` → **OK**.
   - `flutter build web --release` → **OK** (compila; web mostra tela
     "use Android/Linux" porque não há SQLite no navegador).
   - `flutter build linux --debug` → **FALHA** no ambiente por falta de
     `gtk+-3.0` (dev do GTK não instalado). Não é problema do código.

3. **Funcionalidades implementadas**:
   - Busca local (exato → prefixo → FTS5 → substring), tolerante a acentos.
   - Autocomplete (18k termos pré-carregados), buscas recentes, sinal aleatório.
   - Cartões com desenho + termos + fonte; tela de detalhe com zoom, favoritos,
     copiar SWU/FSW, abrir no SignPuddle, vídeo (quando `detail.video`).
   - Metadados pessoais (título, termos, tags, observações) por sinal, editáveis
     e pesquisáveis, gravados no banco do usuário (separado).
   - Sinais manuais (SWU/FSW com prévia ao vivo), editar/excluir.
   - Favoritos, exportar/importar JSON (clipboard), tema claro/escuro.
   - Banco base read-only copiado do asset; banco do usuário `user_data.db`
     separado (atualizar o base não apaga dados do usuário).

4. **Validado em aparelho real** (Samsung Galaxy A55, `adb`):
   - `adb install` OK; app abriu (`MainActivity` em foco), busca abriu teclado.
   - Encontrado (via logcat) o bug de SVG da seção 5.

---

## 5. RENDERIZAÇÃO NATIVA POR FONTES TTF (Abordagem A — Concluída com Sucesso)

O problema original de renderização de SVG aninhado foi superado pela implementação da **Abordagem A**:
- **Fontes Oficiais**: `assets/fonts/SuttonSignWritingLine.ttf` e `SuttonSignWritingFill.ttf` adicionadas aos assets do projeto.
- **Parser em Dart (`lib/core/swu_parser.dart`)**: Decodifica SWU (Unicode, armazenado no SQLite) e FSW (ASCII, entrada manual), convertendo as coordenadas espaciais e mapeando os glifos para o Plano 15 (traço) e Plano 16 (preenchimento).
- **Canvas Nativo (`lib/ui/widgets/sign_writing_canvas.dart`)**: Renderiza os sinais diretamente no Canvas do Flutter com aceleração por GPU. Adapta automaticamente as cores para Modo Claro e Modo Escuro.
- **Integração**: `SignWritingImage` atualizado para usar o canvas nativo diretamente quando o sinal possui código SWU/FSW válido, eliminando a dependência de chamadas de rede para desenhar os sinais.
- **Validado em aparelho real**: Testado no Samsung Galaxy A55 com renderização perfeita dos sinais na busca e zero travamentos.

---

## 6. Situação dos Testes e Qualidade

- **Flutter Analyze**: `No issues found!` (0 erros, 0 avisos).
- **Flutter Test**: **26 testes passando** (incluindo testes de parser SWU, canvas e tela inicial).
- **Python Test**: **7 testes passando** (`tools/signpuddle/tests`).
- **Build APK Debug**: OK (`build/app/outputs/flutter-apk/app-debug.apk`).

---

## 7. Comandos rápidos

```bash
cd /home/eduardo/projetos/personal/libras/escrita_de_libras

# Flutter
flutter pub get
flutter analyze
flutter test
flutter build apk --debug

# Python (dados)
pip install -r tools/signpuddle/requirements.txt
python -m tools.signpuddle.sync
python -m unittest discover -s tools/signpuddle/tests -v

# Aparelho real (adb)
adb devices
adb -s RXCX804MPHD install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s RXCX804MPHD shell monkey -p dev.edbn.escrita_de_libras -c android.intent.category.LAUNCHER 1
adb -s RXCX804MPHD logcat -d | grep -iE "flutter|FATAL|AndroidRuntime"
```

---

## 8. Decisões e regras que precisam ser mantidas

- **Normalização** Python (`tools/signpuddle/normalize.py`) e Dart
  (`lib/core/text_normalizer.dart`) devem permanecer idênticas; o banco guarda
  `term_norm` já normalizado.
- **Nunca apagar dados do usuário** ao atualizar o `signpuddle.db`; por isso o
  `user_data.db` é separado.
- Banco base aberto com `readOnly: true`.
- Web compila, mas **não tem SQLite**; manter os guardas `kIsWeb` e a tela
  "use Android/Linux".
- Ao mudar o esquema do banco base: subir `SCHEMA_VERSION`
  (`tools/signpuddle/config.py`) **e** `AppInfo.databaseVersion`
  (`lib/core/app_info.dart`), casando com o `PRAGMA user_version`.
- Regras globais do usuário: nunca usar `rm`/`rm -rf` (usar `trash-put`), e
  `glab` no lugar de `git` para remotes no GitLab da empresa (não é o caso aqui,
  ainda não há git).
