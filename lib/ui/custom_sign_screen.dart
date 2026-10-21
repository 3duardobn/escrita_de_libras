import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_info.dart';
import '../core/text_normalizer.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'widgets/section_card.dart';
import 'widgets/sign_writing_image.dart';

/// Cria ou edita um sinal manual, com SWU/FSW digitado pelo usuário.
class CustomSignScreen extends StatefulWidget {
  const CustomSignScreen({super.key, this.existing});

  final SignEntry? existing;

  @override
  State<CustomSignScreen> createState() => _CustomSignScreenState();
}

class _CustomSignScreenState extends State<CustomSignScreen> {
  final _formKey = GlobalKey<FormState>();
  final _state = AppState.instance;

  late final TextEditingController _title;
  late final TextEditingController _terms;
  late final TextEditingController _sign;
  late final TextEditingController _source;
  late final TextEditingController _note;

  late SignKind _kind;
  Timer? _previewTimer;
  SignEntry? _preview;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _terms = TextEditingController(text: existing?.terms.join(', ') ?? '');
    _sign = TextEditingController(text: existing?.sign ?? '');
    _source = TextEditingController(text: existing?.source ?? '');
    _note = TextEditingController(text: existing?.customNote ?? '');
    _kind = existing?.signKind ?? SignKind.swu;
    _sign.addListener(_schedulePreview);
    _title.addListener(_schedulePreview);
    _terms.addListener(_schedulePreview);
    _schedulePreview();
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _title.dispose();
    _terms.dispose();
    _sign.dispose();
    _source.dispose();
    _note.dispose();
    super.dispose();
  }

  void _schedulePreview() {
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      final sign = _sign.text.trim();
      if (sign.isEmpty) {
        setState(() => _preview = null);
        return;
      }
      final terms = splitTerms(_terms.text);
      final title = _title.text.trim();
      setState(() {
        _preview = SignEntry(
          key: 'preview:${sign.hashCode}:${_kind.name}',
          title: title.isEmpty
              ? (terms.isNotEmpty ? terms.first : 'Prévia')
              : title,
          terms: terms,
          sign: sign,
          signKind: _kind,
          source: _source.text.trim(),
          customNote: _note.text.trim(),
        );
      });
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final terms = splitTerms(_terms.text);
    final title = _title.text.trim();
    if (title.isEmpty && terms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe pelo menos um título ou um termo.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final entry = await _state.saveCustomSign(
        id: widget.existing?.customId,
        title: title,
        terms: terms,
        sign: _sign.text.trim(),
        signKind: _kind,
        source: _source.text.trim(),
        note: _note.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(entry);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar: $error')),
      );
    }
  }

  Future<void> _openSignPuddle() async {
    final uri = Uri.parse(AppInfo.signPuddleClient);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('De onde vem o SignWriting?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No SignPuddle, cada sinal tem uma sequência SWU (Unicode) ou '
              'FSW (ASCII). Copie essa sequência e cole no campo de '
              'SignWriting.',
            ),
            SizedBox(height: 12),
            SelectableText(AppInfo.signPuddleClient),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _launch(uri);
            },
            child: const Text('Abrir site'),
          ),
        ],
      ),
    );
  }

  Future<void> _launch(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o site.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Editar sinal' : 'Novo sinal'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('Salvar'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              editing
                  ? 'Ajuste os dados do seu sinal. O desenho continua vindo '
                        'do SignPuddle.'
                  : 'Crie um sinal que não está no dicionário. Cole o '
                        'SignWriting em SWU ou FSW para ver a prévia.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Título',
                hintText: 'Ex.: Sinal da minha região',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _terms,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Termos de busca',
                hintText: 'Ex.: casa, moradia',
                helperText: 'Separe por vírgula. É por aqui que você vai buscar.',
              ),
            ),
            const SizedBox(height: 16),
            Text('SignWriting', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<SignKind>(
              segments: const [
                ButtonSegment(
                  value: SignKind.swu,
                  label: Text('SWU (Unicode)'),
                ),
                ButtonSegment(
                  value: SignKind.fsw,
                  label: Text('FSW (ASCII)'),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (selection) {
                setState(() => _kind = selection.first);
                _schedulePreview();
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _sign,
              minLines: 3,
              maxLines: 6,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Sequência do sinal',
                hintText: 'Cole aqui a sequência SWU ou FSW',
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe a sequência SWU ou FSW.';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Prévia',
              icon: Icons.visibility_outlined,
              child: _preview == null
                  ? Container(
                      height: 190,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'O desenho aparece aqui.',
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : SignWritingImage(
                      key: ValueKey(_preview!.key),
                      entry: _preview!,
                      height: 210,
                      padding: const EdgeInsets.all(16),
                    ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _source,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Fonte',
                hintText: 'Ex.: criação própria, aula, livro…',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Observações',
                hintText: 'Contexto, variação, exemplo de uso…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _openSignPuddle,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Abrir SignPuddle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
