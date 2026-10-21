import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_info.dart';
import '../core/format.dart';
import '../state/app_state.dart';
import 'widgets/section_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _state = AppState.instance;
  int? _cacheBytes;

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  Future<void> _loadCache() async {
    final bytes = await _state.imageCacheSize();
    if (mounted) setState(() => _cacheBytes = bytes);
  }

  Future<void> _openUrl(String url) async {
    try {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link.')),
      );
    }
  }

  Future<void> _clearCache() async {
    await _state.clearImageCache();
    await _loadCache();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache de imagens limpo.')),
    );
  }

  Future<void> _export() async {
    try {
      final json = await _state.exportData();
      await Clipboard.setData(ClipboardData(text: json));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Backup copiado para a área de transferência em JSON.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível exportar: $error')),
      );
    }
  }

  Future<void> _import() async {
    final controller = TextEditingController();
    final source = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importar dados'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cole o JSON exportado pelo Escrita de Libras. Os itens '
                'existentes com a mesma chave serão substituídos.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 5,
                maxLines: 9,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                ),
                decoration: const InputDecoration(
                  hintText: '{ "app": "Escrita de Libras", ... }',
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) controller.text = data!.text!;
                },
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                label: const Text('Colar da área de transferência'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (source == null || source.trim().isEmpty) return;

    try {
      final counts = await _state.importData(source);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Importado: ${counts['notes'] ?? 0} anotações, '
            '${counts['favorites'] ?? 0} favoritos, '
            '${counts['custom_signs'] ?? 0} sinais manuais.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('JSON inválido ou incompatível: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        final theme = Theme.of(context);
        final meta = _state.meta;
        final builtAt = DateTime.tryParse(meta['built_at'] ?? '');
        final dictionary = meta['dictionary'] ?? AppInfo.dictionaryName;
        return Scaffold(
          appBar: AppBar(title: const Text('Configurações')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  SectionCard(
                    title: 'Dicionário',
                    icon: Icons.menu_book_outlined,
                    child: Column(
                      children: [
                        const InfoRow(
                          label: 'Língua',
                          value: AppInfo.dictionaryLabel,
                        ),
                        InfoRow(label: 'Coleção', value: dictionary),
                        InfoRow(
                          label: 'Sinais',
                          value: formatCount(_state.entryCount),
                        ),
                        InfoRow(
                          label: 'Termos',
                          value: formatCount(_state.termCount),
                        ),
                        InfoRow(
                          label: 'Gerado em',
                          value: builtAt == null
                              ? '—'
                              : formatDate(builtAt, withTime: true),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _openUrl(AppInfo.signPuddleClient),
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('Abrir SignPuddle'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Imagens',
                    icon: Icons.image_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Os desenhos são buscados no SignPuddle sob demanda '
                          'e guardados em cache. O dicionário de sinais '
                          'funciona sem internet; as imagens já vistas também.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _cacheBytes == null
                                    ? 'Calculando…'
                                    : 'Cache: ${formatBytes(_cacheBytes!)}',
                                style: theme.textTheme.labelMedium,
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _cacheBytes == null
                                  ? null
                                  : _clearCache,
                              icon: const Icon(Icons.cleaning_services_outlined),
                              label: const Text('Limpar cache'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Meus dados',
                    icon: Icons.save_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Anotações, favoritos e sinais manuais ficam em um '
                          'banco separado. Exporte para JSON antes de trocar '
                          'de aparelho.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _export,
                              icon: const Icon(Icons.ios_share_rounded),
                              label: const Text('Exportar para clipboard'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _import,
                              icon: const Icon(Icons.download_rounded),
                              label: const Text('Importar JSON'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: _state.recentSearches.isEmpty
                              ? null
                              : _state.clearRecentSearches,
                          icon: const Icon(Icons.history_rounded, size: 18),
                          label: const Text('Limpar buscas recentes'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Aparência',
                    icon: Icons.palette_outlined,
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_rounded),
                          label: Text('Sistema'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_outlined),
                          label: Text('Claro'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_outlined),
                          label: Text('Escuro'),
                        ),
                      ],
                      selected: {_state.themeMode},
                      onSelectionChanged: (values) =>
                          _state.setThemeMode(values.first),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Sobre',
                    icon: Icons.info_outline_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${AppInfo.appName} 1.0.0',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppInfo.tagline,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Os sinais e metadados vêm do dicionário público '
                          '${AppInfo.dictionaryName}, mantido pela comunidade '
                          'do SignPuddle. Cada entrada pertence aos '
                          'colaboradores indicados. O app apenas pesquisa e '
                          'desenha os sinais.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Software livre, licenciado sob GPL-3.0. '
                          'Use por sua conta e risco.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: () => _openUrl(
                                'https://www.gnu.org/licenses/gpl-3.0.html',
                              ),
                              icon: const Icon(Icons.description_outlined),
                              label: const Text('Licença'),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  _openUrl(AppInfo.signPuddleClient),
                              icon: const Icon(Icons.public_rounded),
                              label: const Text('SignPuddle'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
