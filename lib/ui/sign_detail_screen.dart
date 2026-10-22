import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/swu_parser.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import 'theme.dart';
import 'widgets/note_editor_sheet.dart';
import 'widgets/section_card.dart';
import 'widgets/sign_writing_image.dart';

class SignDetailScreen extends StatefulWidget {
  const SignDetailScreen({super.key, required this.entry});

  final SignEntry entry;

  @override
  State<SignDetailScreen> createState() => _SignDetailScreenState();
}

class _SignDetailScreenState extends State<SignDetailScreen> {
  final AppState _state = AppState.instance;
  late SignEntry _entry;
  SignNote? _note;
  bool _noteLoaded = false;
  bool _isInteractingWithSign = false;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _loadNote();
  }

  Future<void> _loadNote() async {
    if (_entry.isCustom) {
      _noteLoaded = true;
      return;
    }
    final cached = _state.cachedNote(_entry);
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _note = cached;
        _noteLoaded = true;
      });
      return;
    }
    final note = await _state.noteFor(_entry);
    if (!mounted) return;
    setState(() {
      _note = note;
      _noteLoaded = true;
    });
  }

  String get _displayTitle {
    final custom = _note?.customTitle.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return _entry.title;
  }

  List<String> get _allTerms {
    final terms = <String>[..._entry.terms];
    for (final term in _note?.terms ?? const <String>[]) {
      if (!terms.contains(term)) terms.add(term);
    }
    return terms;
  }

  Future<void> _toggleFavorite() async {
    await _state.toggleFavorite(_entry);
    if (!mounted) return;
    final favorite = _state.isFavorite(_entry);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          favorite
              ? 'Sinal adicionado aos favoritos.'
              : 'Sinal removido dos favoritos.',
        ),
      ),
    );
  }

  Future<void> _copySign() async {
    await Clipboard.setData(ClipboardData(text: _entry.sign));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SignWriting copiado.')),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link.')),
      );
    }
  }

  Future<void> _editNote() async {
    final note = await showNoteEditor(
      context,
      entry: _entry,
      note: _note,
    );
    if (note == null) return;
    await _state.saveNote(note);
    if (!mounted) return;
    setState(() => _note = note.isEmpty ? null : note);
  }

  void _openFullscreenSign() {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF111418)
            : const Color(0xFFF9F7F4),
        child: Stack(
          children: [
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: SignWritingImage(
                  entry: _entry,
                  height: MediaQuery.of(context).size.height,
                  interactive: true,
                  padding: const EdgeInsets.all(48),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Fechar',
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Arraste ou use pinça para zoom',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        final theme = Theme.of(context);
        final favorite = _state.isFavorite(_entry);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Sinal'),
            actions: [
              IconButton(
                onPressed: _toggleFavorite,
                tooltip: favorite ? 'Remover dos favoritos' : 'Favoritar',
                icon: Icon(
                  favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: favorite ? const Color(0xFFD97706) : null,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'note':
                      _editNote();
                    case 'copy':
                      _copySign();
                    case 'open':
                      if (_entry.entryUrl != null) _openUrl(_entry.entryUrl!);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'note',
                    child: Text('Editar meus metadados'),
                  ),
                  const PopupMenuItem(
                    value: 'copy',
                    child: Text('Copiar SignWriting'),
                  ),
                  if (_entry.entryUrl != null)
                    const PopupMenuItem(
                      value: 'open',
                      child: Text('Abrir no SignPuddle'),
                    ),
                ],
              ),
            ],
          ),
          body: ListView(
            physics: _isInteractingWithSign
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Stack(
                children: [
                  Listener(
                    onPointerDown: (_) {
                      if (!_isInteractingWithSign) {
                        setState(() => _isInteractingWithSign = true);
                      }
                    },
                    onPointerUp: (_) {
                      if (_isInteractingWithSign) {
                        setState(() => _isInteractingWithSign = false);
                      }
                    },
                    onPointerCancel: (_) {
                      if (_isInteractingWithSign) {
                        setState(() => _isInteractingWithSign = false);
                      }
                    },
                    child: SignWritingImage(
                      entry: _entry,
                      height: 340,
                      interactive: true,
                      padding: const EdgeInsets.all(20),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton.filledTonal(
                      onPressed: _openFullscreenSign,
                      icon: const Icon(Icons.fullscreen_rounded, size: 20),
                      tooltip: 'Ver em tela cheia (zoom livre)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _displayTitle,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  if (_entry.isCustom)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.14,
                        ),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        'MEU SINAL',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (_allTerms.isNotEmpty)
                SignTermChips(
                  terms: _allTerms,
                  max: 12,
                  highlight: (_note?.terms ?? const <String>[]).toSet(),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.account_balance_outlined,
                    size: 15,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      [
                        _entry.sourceLabel,
                        if (!_entry.isCustom) '#${_entry.shortId}',
                        if (_entry.fromSigntext) 'texto SignWriting',
                      ].join(' • '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              if ((_entry.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                SectionCard(
                  title: 'Descrição',
                  icon: Icons.notes_rounded,
                  child: Text(
                    _entry.description!.trim(),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _buildUserSection(theme),
              const SizedBox(height: 14),
              _buildSignPuddleSection(theme),
              if (_entry.videoUrl != null) ...[
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Vídeo',
                  icon: Icons.play_circle_outline_rounded,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _openUrl(_entry.videoUrl!),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Abrir vídeo'),
                    ),
                  ),
                ),
              ],
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _toggleFavorite,
                    icon: Icon(
                      favorite
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                    ),
                    label: Text(favorite ? 'Favoritado' : 'Favoritar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copySign,
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copiar código'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserSection(ThemeData theme) {
    final isCustom = _entry.isCustom;
    final note = _note;
    final noteText = isCustom
        ? (_entry.customNote?.trim() ?? '')
        : (note?.note.trim() ?? '');
    final terms = isCustom ? _entry.terms : (note?.terms ?? const <String>[]);
    final tags = note?.tags ?? const <String>[];
    final hasData = isCustom
        ? noteText.isNotEmpty
        : (note != null && !note.isEmpty);

    return SectionCard(
      title: 'Meus metadados',
      icon: Icons.edit_note_rounded,
      action: IconButton(
        onPressed: _editNote,
        tooltip: 'Editar metadados',
        icon: const Icon(Icons.edit_outlined, size: 20),
      ),
      child: !_noteLoaded && !isCustom
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 2),
            )
          : !hasData
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dê um título pessoal, acrescente termos, tags ou '
                  'observações. Tudo entra na busca.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _editNote,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Adicionar metadados'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (noteText.isNotEmpty)
                  Text(noteText, style: theme.textTheme.bodyLarge),
                if (terms.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Termos', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 6),
                  SignTermChips(terms: terms, max: 12),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Tags', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in tags)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppRadius.chip,
                            ),
                          ),
                          child: Text(
                            '#$tag',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (!isCustom && note?.updatedAt != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Atualizado em ${formatDate(note!.updatedAt, withTime: true)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildSignPuddleSection(ThemeData theme) {
    final fswCode = _entry.signKind == SignKind.fsw
        ? _entry.sign
        : SwuParser.swuToFsw(_entry.sign);
    final isSwu = _entry.signKind == SignKind.swu;

    return SectionCard(
      title: 'Dados do SignPuddle',
      icon: Icons.data_object_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Código Formal SignWriting (FSW)',
                style: theme.textTheme.labelMedium,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'ASCII',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(
              fswCode.isNotEmpty ? fswCode : _entry.sign,
              maxLines: 5,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                    text: fswCode.isNotEmpty ? fswCode : _entry.sign,
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Código FSW (ASCII) copiado!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: const Text('Copiar FSW'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
              if (isSwu)
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _entry.sign));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Código SWU (Unicode) copiado!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.code_rounded, size: 15),
                  label: const Text('Copiar SWU'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (!_entry.isCustom) ...[
            InfoRow(label: 'Colaborador', value: _entry.userName ?? '—'),
            InfoRow(
              label: 'Criado em',
              value: formatDate(_entry.createdAt),
            ),
            InfoRow(
              label: 'Atualizado em',
              value: formatDate(_entry.updatedAt),
            ),
          ] else
            const InfoRow(
              label: 'Origem',
              value: 'Criado manualmente neste aparelho',
            ),
          if (_entry.entryUrl != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _openUrl(_entry.entryUrl!),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Ver no SignPuddle'),
            ),
          ],
        ],
      ),
    );
  }
}
