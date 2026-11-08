# TODO / Roadmap — Escrita de Libras

Lista de tarefas, melhorias planejadas e fontes adicionais para indexação no projeto.

---

## 📌 Fontes para Indexação

### 1. [LibrasLab](https://libraslab.com.br) (YouTube & Plataforma Web)
- **Status**: 📋 Planejado / Na fila para análise e scraper
- **Origem / Links**:
  - **Canal YouTube**: [youtube.com/@LibrasLab](https://www.youtube.com/@LibrasLab)
  - **Página de Vídeos**: [youtube.com/@LibrasLab/videos](https://www.youtube.com/@LibrasLab/videos)
  - **Site Oficial**: [libraslab.com.br](https://libraslab.com.br)
  - **Sinalário / Glossário**: [libraslab.com.br/sinais](https://libraslab.com.br)
- **Conteúdo Disponível**:
  - ~400 vídeos curtos de demonstração no YouTube, focados em termos individuais do cotidiano, expressões, números e alfabeto manual de Libras.
  - Sinalário interativo no portal web e aplicativo (Android/iOS).
- **Objetivo da Indexação**:
  - Extrair o mapeamento de termos em português ↔ vídeos de demonstração de sinais de Libras.
  - Enriquecer as entradas existentes do banco de dados (por exemplo, preenchendo o campo `video` no `detail_json` de sinais compatíveis) ou disponibilizar uma base de busca com referências em vídeo.
- **Plano de Implementação**:
  - [ ] **1. Mapeamento e Crawler**: Criar script Python (ex.: `tools/libraslab/fetch_channel.py`) para coletar metadados dos vídeos (título, ID do YouTube, termos correspondentes).
  - [ ] **2. Investigação do Sinalário Web/App**: Mapear endpoints públicos ou estrutura de dados do site oficial para coletar termos adicionais.
  - [ ] **3. Normalização**: Integrar com a regra de normalização unificada do projeto (`tools/signpuddle/normalize.py` e `lib/core/text_normalizer.dart`).
  - [ ] **4. Casamento de Dados (Matching)**: Cruzar os termos do LibrasLab com os termos do dicionário base (`signpuddle.db`), associando os links de vídeo aos sinais SWU correspondentes.
  - [ ] **5. Testes Unitários**: Criar testes automatizados para o parser/extrator do LibrasLab.

---

### 2. [Sinais diários de Libras](https://www.youtube.com/@Sinaisdi%C3%A1riosdeLibras) (Canal YouTube — Carlos Cristian)
- **Status**: 📋 Planejado / Prioritário para indexação de vídeos
- **Origem / Links**:
  - **Canal YouTube**: [youtube.com/@SinaisdiáriosdeLibras](https://www.youtube.com/@Sinaisdi%C3%A1riosdeLibras)
  - **Criador**: Prof. Carlos Cristian de Paulo Silva
- **Conteúdo Disponível**:
  - **Mais de 3.500 vídeos** publicados, estruturados no formato de **dicionário em vídeo** (1 sinal por vídeo com título em português e demonstração em Libras).
  - Organizado em dezenas de playlists temáticas (saúde, direito, família, verbos, profissões, etc.) e séries sobre Escrita de Sinais (*SignWriting*).
- **Objetivo da Indexação**:
  - Extrair o mapeamento de termos e títulos de vídeos para enriquecer o acervo de demonstrações em vídeo (`detail_json.video`) dos sinais já existentes em `signpuddle.db`.
  - Cruzar os termos com a nossa base de 25k sinais para elevar significativamente a cobertura de vídeos reais de sinais de Libras (atualmente apenas 284 sinais possuem URL de vídeo no banco base).
- **Plano de Implementação**:
  - [ ] **1. Scraper do Canal / Playlists**: Criar ferramenta em Python (ex.: `tools/carlos_cristian/fetch_sinais_diarios.py`) para coletar títulos, IDs e URLs de vídeos via YouTube Data API ou extração de metadados das playlists públicas.
  - [ ] **2. Normalização**: Aplicar `tools/signpuddle/normalize.py` aos termos e títulos extraídos.
  - [ ] **3. Matching com `terms` do SQLite**: Gerar script de vinculação para preencher `detail_json` com o link do vídeo correspondente.
  - [ ] **4. Testes e Validação**: Validar precisão dos termos casados e integridade dos links.

---

### 3. [Carlos Cristian Libras](https://www.youtube.com/c/CarlosCristianLibras) (Canal YouTube — Cursos e SignWriting)
- **Status**: 📋 Planejado / Na fila para análise de conteúdo
- **Origem / Links**:
  - **Canal YouTube**: [youtube.com/c/CarlosCristianLibras](https://www.youtube.com/c/CarlosCristianLibras) (`@CarlosCristianLibras`)
  - **Criador**: Prof. Carlos Cristian de Paulo Silva
- **Conteúdo Disponível**:
  - **Mais de 2.600 vídeos** de cursos completos de Libras (básico, intermediário, avançado), oficinas de *SignWriting* / *SignPuddle*, figuras de linguagem e cultura surda.
- **Objetivo da Indexação**:
  - Avaliar extração de vocabulário e referências de aulas de *SignWriting* e glossários contextuais presentes nas descrições e capítulos dos vídeos.
- **Plano de Implementação**:
  - [ ] **1. Mapeamento de Playlists de SignWriting e Vocabulário**: Identificar playlists com conteúdos diretamente relacionados a escrita de sinais e termos específicos.
  - [ ] **2. Extração de Metadados e Referências**: Catalogar links relevantes para possíveis materiais de apoio ou referências de estudos no app.

---

### 4. [Glossário Letras-Libras UFRJ](https://www.youtube.com/@GlossarioLetras-LibrasUFRJ) (UFRJ / ViA Libras)
- **Status**: 📋 Planejado / Na fila para indexação de glossários acadêmicos
- **Origem / Links**:
  - **Canal YouTube**: [youtube.com/@GlossarioLetras-LibrasUFRJ](https://www.youtube.com/@GlossarioLetras-LibrasUFRJ) (também associado ao [`@LetrasLibrasUFRJ`](https://www.youtube.com/@LetrasLibrasUFRJ))
  - **Instituição**: Faculdade de Letras — Departamento de Letras-Libras da Universidade Federal do Rio de Janeiro (UFRJ)
  - **Projeto Institucional**: Videoteca Acadêmica em Libras (*ViA Libras*) / Curso de Extensão "Libras para todos"
- **Conteúdo Disponível**:
  - **Aproximadamente 260 vídeos** com glossários terminológicos formais e educacionais (cores, números, pronomes, verbos, termos acadêmicos, escolares e de saúde) gravados com rigor linguístico por docentes e estudantes do curso de Letras-Libras.
- **Objetivo da Indexação**:
  - Mapear termos acadêmicos e educacionais em Libras de fonte universitária oficial de alta autoridade linguística.
  - Vincular os vídeos como fonte demonstrativa qualificada no banco de dados.
- **Plano de Implementação**:
  - [ ] **1. Extração de Metadados**: Coletar títulos de vídeos, termos do glossário e URLs.
  - [ ] **2. Normalização**: Aplicar normalização de termos com `tools/signpuddle/normalize.py`.
  - [ ] **3. Associação com o Banco Local**: Relacionar termos com sinais de `signpuddle.db` (enriquecimento de `detail_json.video` e `source`).
  - [ ] **4. Testes**: Garantir cobertura em testes unitários Python.

---

## 📋 Outras Tarefas e Melhorias Gerais

- [ ] **Expansão de Dicionários de Libras**: Identificar e catalogar outras fontes abertas e públicas estritamente de Libras.
- [ ] **Otimização de FTS**: Ajustar pesos de relevância na busca textual por termos exatos vs. anotações do usuário.
- [ ] **Exportação / Compartilhamento de Sinais**: Permitir exportar a imagem do sinal renderizado em PNG/SVG a partir do canvas nativo.
