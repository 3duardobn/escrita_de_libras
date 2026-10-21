import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import 'sign_detail_screen.dart';
import 'widgets/section_card.dart';
import 'widgets/sign_card.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _state = AppState.instance;
  late Future<List<SignEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _state.favoriteEntries();
  }

  void _reload() {
    setState(() => _future = _state.favoriteEntries());
  }

  Future<void> _toggle(SignEntry entry) async {
    await _state.toggleFavorite(entry);
    if (!mounted) return;
    if (!_state.isFavorite(entry)) {
      _reload();
    } else {
      setState(() {});
    }
  }

  Future<void> _openDetail(SignEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SignDetailScreen(entry: entry)),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: FutureBuilder<List<SignEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Não foi possível carregar',
              message: '${snapshot.error}',
              action: FilledButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar de novo'),
              ),
            );
          }
          final entries = snapshot.data ?? const <SignEntry>[];
          if (entries.isEmpty) {
            return const EmptyState(
              icon: Icons.star_outline_rounded,
              title: 'Nenhum favorito ainda',
              message:
                  'Toque na estrela de um sinal para guardá-lo aqui e '
                  'encontrá-lo rapidinho depois.',
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return SignCard(
                    entry: entry,
                    note: _state.cachedNote(entry),
                    isFavorite: _state.isFavorite(entry),
                    onTap: () => _openDetail(entry),
                    onFavorite: () => _toggle(entry),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
