import 'package:flutter/material.dart';

import '../../core/text_normalizer.dart';
import '../../data/models.dart';

Future<SignNote?> showNoteEditor(
  BuildContext context, {
  required SignEntry entry,
  SignNote? note,
}) {
  return showModalBottomSheet<SignNote>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.92,
      child: NoteEditorSheet(entry: entry, note: note),
    ),
  );
}

class NoteEditorSheet extends StatefulWidget {
  const NoteEditorSheet({super.key, required this.entry, this.note});

  final SignEntry entry;
  final SignNote? note;

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _terms;
  late final TextEditingController _tags;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.customTitle ?? '');
    _terms = TextEditingController(text: widget.note?.terms.join(', ') ?? '');
    _tags = TextEditingController(text: widget.note?.tags.join(', ') ?? '');
    _note = TextEditingController(text: widget.note?.note ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _terms.dispose();
    _tags.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final note = SignNote(
      signKey: widget.entry.key,
      customTitle: _title.text.trim(),
      terms: splitTerms(_terms.text),
      tags: splitTerms(_tags.text),
      note: _note.text.trim(),
      updatedAt: DateTime.now(),
    );
    Navigator.of(context).pop(note);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Meus metadados', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Ficam só neste aparelho e também entram na busca.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                TextField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Título pessoal',
                    hintText: 'Ex.: Casa (variante que eu uso)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _terms,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Termos pessoais',
                    hintText: 'Separe por vírgula',
                    helperText: 'Aparecem junto dos termos do dicionário.',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tags,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Tags',
                    hintText: 'Ex.: aula, família, região',
                    helperText: 'Também são pesquisáveis.',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  minLines: 5,
                  maxLines: 10,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Observações',
                    hintText:
                        'Contexto, variação regional, exemplo de uso, o que '
                        'mais ajudar você a lembrar.',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Salvar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
