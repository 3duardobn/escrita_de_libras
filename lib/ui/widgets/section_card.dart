import 'package:flutter/material.dart';

import '../theme.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.action,
    this.padding = const EdgeInsets.all(16),
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? action;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 19,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.monospace = false,
    this.trailing,
  });

  final String label;
  final String value;
  final bool monospace;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(label, style: theme.textTheme.labelMedium),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: monospace ? 'monospace' : null,
                fontSize: monospace ? 12.5 : null,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 32,
          vertical: compact ? 24 : 48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                size: 30,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class SignTermChips extends StatelessWidget {
  const SignTermChips({
    super.key,
    required this.terms,
    this.max = 8,
    this.highlight = const {},
  });

  final List<String> terms;
  final int max;
  final Set<String> highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = terms.take(max).toList(growable: false);
    final hidden = terms.length - visible.length;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final term in visible)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: highlight.contains(term)
                  ? theme.colorScheme.secondary.withValues(alpha: 0.14)
                  : theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Text(
              term,
              style: theme.textTheme.labelMedium?.copyWith(
                color: highlight.contains(term)
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        if (hidden > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Text(
              '+$hidden',
              style: theme.textTheme.labelMedium,
            ),
          ),
      ],
    );
  }
}
