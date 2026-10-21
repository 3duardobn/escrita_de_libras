import 'package:flutter/material.dart';

import '../../data/models.dart';
import 'section_card.dart';
import 'sign_writing_image.dart';

class SignCard extends StatelessWidget {
  const SignCard({
    super.key,
    required this.entry,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
    this.note,
  });

  final SignEntry entry;
  final SignNote? note;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayTitle = (note?.customTitle.trim().isNotEmpty ?? false)
        ? note!.customTitle.trim()
        : entry.title;
    final allTerms = {...entry.terms, ...?note?.terms}.toList(growable: false);
    final noteText = entry.isCustom
        ? (entry.customNote?.trim() ?? '')
        : (note?.note.trim() ?? '');
    final preview = (entry.description?.trim().isNotEmpty ?? false)
        ? entry.description!.trim()
        : noteText;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 118,
                child: SignWritingImage(
                  entry: entry,
                  height: 118,
                  padding: const EdgeInsets.all(9),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              displayTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 17,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: onFavorite,
                          tooltip: isFavorite
                              ? 'Remover dos favoritos'
                              : 'Adicionar aos favoritos',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            isFavorite
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: isFavorite
                                ? const Color(0xFFD97706)
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if (entry.isCustom)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withValues(
                              alpha: 0.14,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'MEU SINAL',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.secondary,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                      ),
                    if (allTerms.isNotEmpty)
                      SignTermChips(terms: allTerms, max: 5),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_outlined,
                          size: 13,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            entry.sourceLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        if (!entry.isCustom && note != null)
                          Icon(
                            Icons.edit_note_rounded,
                            size: 16,
                            color: theme.colorScheme.secondary,
                          ),
                      ],
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
