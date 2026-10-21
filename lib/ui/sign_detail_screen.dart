import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import 'custom_sign_screen.dart';
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

  Future<void> _editCustom() async {
    final updated = await Navigator.of(context).push<SignEntry>(
      MaterialPageRoute(
        builder: (_) => CustomSignScreen(existing: _entry),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => _entry = updated);
  }

  Future<void> _deleteCustom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir sinal manual?'),
        content: const Text(
          'O sinal e a anotação serão apagados deste aparelho. '
          'Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _state.deleteCustomSign(_entry);
    if (mounted) Navigator.of(context).pop();
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
                    case 'edit':
                      _editCustom();
                    case 'copy':
                      _copySign();
                    case 'open':
                      if (_entry.entryUrl != null) _openUrl(_entry.entryUrl!);
                    case 'delete':
                      _deleteCustom();
                  }
                },
                itemBuilder: (context) => [
                  if (!_entry.isCustom)
                    const PopupMenuItem(
                      value: 'note',
                      child: Text('Editar meus metadados'),
                    ),
                  if (_entry.isCustom)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Editar sinal manual'),
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
                  if (_entry.isCustom) ...[
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Excluir sinal',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              SignWritingImage(
                entry: _entry,
                height: 340,
                interactive: true,
                padding: const EdgeInsets.all(20),
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
        onPressed: isCustom ? _editCustom : _editNote,
        tooltip: isCustom ? 'Editar sinal manual' : 'Editar metadados',
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
                  isCustom
                      ? 'Adicione uma observação ao seu sinal.'
                      : 'Dê um título pessoal, acrescente termos, tags ou '
                            'observações. Tudo entra na busca.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: isCustom ? _editCustom : _editNote,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(isCustom ? 'Editar sinal' : 'Adicionar metadados'),
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
    return SectionCard(
      title: 'Dados do SignPuddle',
      icon: Icons.data_object_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SignWriting (${_entry.signKind == SignKind.swu ? 'SWU' : 'FSW'})',
              style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(
              _entry.sign,
              maxLines: 5,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
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
