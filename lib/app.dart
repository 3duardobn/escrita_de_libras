import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/app_info.dart';
import 'state/app_state.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

class EscritaDeLibrasApp extends StatelessWidget {
  const EscritaDeLibrasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;
        return MaterialApp(
          title: AppInfo.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: state.themeMode,
          home: !state.initialized
              ? const _SplashScreen()
              : state.startupError != null
              ? const _StartupProblemScreen()
              : const HomeScreen(),
        );
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sign_language_rounded,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              AppInfo.appName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            const SizedBox(
              width: 120,
              child: LinearProgressIndicator(minHeight: 3),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartupProblemScreen extends StatefulWidget {
  const _StartupProblemScreen();

  @override
  State<_StartupProblemScreen> createState() => _StartupProblemScreenState();
}

class _StartupProblemScreenState extends State<_StartupProblemScreen> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    await AppState.instance.init();
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final theme = Theme.of(context);
    final web = kIsWeb;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    web ? Icons.computer_outlined : Icons.storage_rounded,
                    size: 34,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  web ? 'Use a versão Android ou Linux' : 'Banco indisponível',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  web
                      ? 'A busca usa um banco SQLite local, que não funciona '
                            'no navegador. O mesmo projeto roda em Android e '
                            'Linux.'
                      : 'Não consegui abrir o dicionário local. '
                            '${state.startupError}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                if (!web) ...[
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _retrying ? null : _retry,
                    icon: _retrying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: const Text('Tentar de novo'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
