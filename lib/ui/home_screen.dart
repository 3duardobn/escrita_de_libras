import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_info.dart';
import '../core/format.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'favorites_screen.dart';
import 'settings_screen.dart';
import 'sign_detail_screen.dart';
import 'theme.dart';
import 'widgets/section_card.dart';
import 'widgets/sign_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _state = AppState.instance;
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _randomLoading = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_redraw);
    _focus.addListener(_redraw);
  }

  @override
  void dispose() {
    _controller.removeListener(_redraw);
    _focus.removeListener(_redraw);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  Future<void> _submit([String? value]) async {
    final query = (value ?? _controller.text).trim();
    if (query.isEmpty) return;
    if (value != null) {
      _controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    _focus.unfocus();
    await _state.search(query);
  }

  Future<void> _openDetail(SignEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SignDetailScreen(entry: entry)),
    );
  }

  Future<void> _openRandom() async {
    if (_randomLoading) return;
    setState(() => _randomLoading = true);
    try {
      final entry = await _state.randomEntry();
      if (!mounted) return;
      if (entry == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não encontrei um sinal disponível.')),
        );
        return;
      }
      await _openDetail(entry);
    } finally {
      if (mounted) setState(() => _randomLoading = false);
    }
  }

  void _openFavorites() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FavoritesScreen()),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _clear() {
    _controller.clear();
    _state.clearSearch();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(AppInfo.appName),
                Text(
                  'SignPuddle • Libras',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                ),
              ],
            ),
            actions: [
              Badge.count(
                count: _state.favorites.length,
                isLabelVisible: _state.favorites.isNotEmpty,
                child: IconButton(
                  tooltip: 'Favoritos',
                  onPressed: _openFavorites,
                  icon: const Icon(Icons.star_outline_rounded),
                ),
              ),
              IconButton(
                tooltip: 'Aparência',
                onPressed: _state.toggleTheme,
                icon: Icon(
                  _state.themeMode == ThemeMode.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
              ),
              IconButton(
                tooltip: 'Configurações',
                onPressed: _openSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                children: [
                  _SearchPanel(
                    controller: _controller,
                    focusNode: _focus,
                    suggestions: _focus.hasFocus
                        ? _state.suggestionsFor(_controller.text)
                        : const [],
                    onSubmit: _submit,
                    onClear: _clear,
                  ),
                  if (_state.searching) const LinearProgressIndicator(minHeight: 2),
                  Expanded(child: _buildBody(theme)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_state.error != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Algo deu errado',
        message: _state.error!,
        action: FilledButton.icon(
          onPressed: () => _state.search(
            _state.lastQuery ?? _controller.text,
          ),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tentar de novo'),
        ),
      );
    }

    if (_state.lastQuery == null) {
      return _WelcomeView(
        state: _state,
        onSuggestion: _submit,
        onRandom: _openRandom,
        randomLoading: _randomLoading,
        onClearRecent: _state.clearRecentSearches,
        onRemoveRecent: _state.removeRecent,
      );
    }

    if (_state.results.isEmpty && !_state.searching) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Nenhum sinal para “${_state.lastQuery}”',
        message: 'Tente uma palavra mais curta ou o singular.',
        action: OutlinedButton.icon(
          onPressed: _clear,
          icon: const Icon(Icons.close_rounded),
          label: const Text('Limpar busca'),
        ),
      );
    }

    final results = _state.results;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  results.length == 1
                      ? '1 resultado'
                      : '${formatCount(results.length)} resultados',
                  style: theme.textTheme.labelMedium,
                ),
              ),
              TextButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Limpar'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
            itemCount: results.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = results[index];
              return SignCard(
                entry: entry,
                note: _state.cachedNote(entry),
                isFavorite: _state.isFavorite(entry),
                onTap: () => _openDetail(entry),
                onFavorite: () => _state.toggleFavorite(entry),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.focusNode,
    required this.suggestions,
    required this.onSubmit,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> suggestions;
  final Future<void> Function([String?]) onSubmit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.search,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => onSubmit(),
                  decoration: InputDecoration(
                    hintText: 'Pesquise uma palavra em português…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: controller.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpar',
                            onPressed: onClear,
                            icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 58,
                height: 56,
                child: FilledButton(
                  onPressed: () => onSubmit(),
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                    ),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ],
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: suggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final term = suggestions[index];
                  return ActionChip(
                    label: Text(term),
                    onPressed: () => onSubmit(term),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WelcomeView extends StatelessWidget {
  const _WelcomeView({
    required this.state,
    required this.onSuggestion,
    required this.onRandom,
    required this.randomLoading,
    required this.onClearRecent,
    required this.onRemoveRecent,
  });

  final AppState state;
  final Future<void> Function([String?]) onSuggestion;
  final Future<void> Function() onRandom;
  final bool randomLoading;
  final Future<void> Function() onClearRecent;
  final void Function(String) onRemoveRecent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pesquise em português.',
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'O app encontra o termo no banco local e busca o '
                            'desenho em SignWriting no SignPuddle.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 108,
                        height: 108,
                        color: AppColors.paper,
                        padding: const EdgeInsets.all(8),
                        child: SvgPicture.asset(
                          'assets/sample_sign.svg',
                          fit: BoxFit.contain,
                          semanticsLabel: 'SignWriting de água',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _StatPill(text: '${formatCount(state.entryCount)} sinais'),
                    _StatPill(text: '${formatCount(state.termCount)} termos'),
                    const _StatPill(text: 'SignPuddle'),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: randomLoading ? null : onRandom,
                    icon: randomLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.casino_outlined),
                    label: const Text('Sinal aleatório'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (state.recentSearches.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Buscas recentes',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: onClearRecent,
                child: const Text('Limpar'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final query in state.recentSearches)
                InputChip(
                  label: Text(query),
                  onPressed: () => onSuggestion(query),
                  onDeleted: () => onRemoveRecent(query),
                  deleteIcon: const Icon(Icons.close_rounded, size: 16),
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        SectionCard(
          title: 'Como funciona',
          icon: Icons.info_outline_rounded,
          child: Text(
            'A busca e seus metadados ficam no aparelho. Os desenhos são '
            'buscados no servidor público do SignPuddle na primeira vez e '
            'depois ficam em cache. Se quiser uso totalmente offline, rode o '
            'script Python com --into-db para embutir os SVGs no banco.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(text, style: theme.textTheme.labelMedium),
    );
  }
}
