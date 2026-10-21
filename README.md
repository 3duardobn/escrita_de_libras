# Escrita de Libras

App para pesquisar sinais de **Libras** e ver o desenho em **SignWriting**,
usando o dicionário público brasileiro do [SignPuddle](https://signpuddle.com/).

Você digita uma palavra em português, o app encontra o termo num **SQLite
local** e busca o desenho (SVG) no servidor do SignPuddle na primeira vez.
Depois, o desenho fica em cache. Também dá para salvar **metadados próprios**
(título, termos, tags e observações) em cima de qualquer sinal e criar **sinais
manuais**.

## Funcionalidades

- **Busca local** em ~25.611 sinais e ~39.802 termos (dicionário
  `bzs-BR-dictionary-public`), com acentos/tolerância de pontuação, prefixo,
  FTS5 e substring.
- **Desenho SignWriting** baixado sob demanda do SignPuddle e guardado em
  cache (memória → blob opcional → arquivo → rede).
- **Metadados pessoais** por sinal: título, termos extras, tags e observações —
  tudo entra na busca e fica só no aparelho.
- **Sinais manuais**: crie um sinal colando o SWU (Unicode) ou FSW (ASCII), com
  prévia ao vivo.
- **Favoritos** e **buscas recentes**.
- **Exportar/importar** seus dados (anotações, favoritos e sinais manuais) em
  JSON, pela área de transferência.
- Tema claro/escuro.

## Plataformas

- **Android**: completo.
- **Linux** (desktop): completo (requer `libsqlite3`).
- **Web**: a busca usa SQLite local e **não** funciona no navegador; o app
  mostra uma mensagem orientando a usar Android/Linux. O mesmo código compila.

## Estrutura

```
lib/
  core/        normalização, URLs, formato, info do app
  data/        SQLite base (somente leitura) + banco do usuário + repositório
  services/    serviço de imagem (cache + rede)
  state/       estado global (ChangeNotifier)
  ui/          telas e widgets
tools/signpuddle/
  fetch_dictionary.py   baixa o JSON do SignPuddle
  build_sqlite.py       gera assets/signpuddle.db (pesquisável)
  download_images.py    espelha SVGs (opcional) e/ou embute no banco
  sync.py               faz fetch + build de uma vez
  list_dictionaries.py  lista os dicionários públicos
assets/
  signpuddle.db         banco gerado (asset do app)
  sample_sign.svg       exemplo de desenho para a tela inicial
```

## Como rodar o app

```bash
flutter pub get
flutter run              # Android/Linux
flutter test             # testes
flutter analyze
```

O banco `assets/signpuddle.db` já vem pronto. Para regerá-lo (ou atualizar do
SignPuddle):

```bash
pip install -r tools/signpuddle/requirements.txt
python -m tools.signpuddle.sync
```

Isso baixa o JSON (~20 MB) para `tools/signpuddle/data/raw/` e reconstrói o
SQLite. O diretório `tools/signpuddle/data/` fica fora do git (ver
`.gitignore`); apenas o `.db` final é versionado como asset.

## Imagens offline (opcional)

Por padrão, os desenhos são buscados no SignPuddle sob demanda. Para ter tudo
embutido no banco (uso totalmente offline, à custa de ~50 MB a mais):

```bash
python -m tools.signpuddle.download_images --all --into-db
```

O app detecta a tabela `sign_images` e usa o blob antes de ir para a rede.

## Testes

```bash
# Dart/Flutter
flutter test

# Python (normalização e geração do banco)
python -m unittest discover -s tools/signpuddle/tests -v
```

## Dados e atribuição

Os sinais e metadados vêm do dicionário público
`bzs-BR-dictionary-public`, mantido pela comunidade do SignPuddle (SignWriting
de Valerie Sutton, software de Steve Slevinski). Cada entrada pertence aos
colaboradores indicados no campo `source`. Este projeto apenas pesquisa e
desenha os sinais; não se responsabiliza pelo conteúdo.

## Licença

Este software é livre, sob [GPL-3.0](LICENSE). Os dados do SignPuddle seguem as
condições do próprio SignPuddle/colaboradores.

Desenvolvido para estudo de Libras. Use por sua conta e risco.
