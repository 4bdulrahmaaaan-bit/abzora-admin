import 'package:flutter/material.dart';

import '../config/product_attribute_config.dart';
import '../theme.dart';

class ProductAttributes extends StatelessWidget {
  const ProductAttributes({
    super.key,
    required this.category,
    required this.attributes,
  });

  final String category;
  final Map<String, dynamic> attributes;

  @override
  Widget build(BuildContext context) {
    final cleanedAttributes = <String, String>{};
    for (final entry in attributes.entries) {
      final key = entry.key.trim().toLowerCase();
      final value = '${entry.value ?? ''}'.trim();
      if (key.isEmpty || value.isEmpty) {
        continue;
      }
      cleanedAttributes[key] = value;
    }

    if (cleanedAttributes.isEmpty) {
      return const SizedBox.shrink();
    }

    final config = productAttributeConfig[normalizeProductCategory(category)];
    final sections = config?.sections ??
        const [
          ProductAttributeSectionConfig(
            title: 'Product Details',
            fields: genericAttributeFields,
          ),
        ];

    final visibleSections = sections
        .map((section) {
          final rows = section.fields
              .where((field) => cleanedAttributes.containsKey(field))
              .map((field) => MapEntry(field, cleanedAttributes[field]!))
              .toList();
          return MapEntry(section.title, rows);
        })
        .where((entry) => entry.value.isNotEmpty)
        .toList();

    if (visibleSections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < visibleSections.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            Text(
              visibleSections[i].key,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: visibleSections[i].value
                      .map(
                        (entry) => SizedBox(
                          width: tileWidth,
                          child: _AttributeTile(
                            label: humanizeAttributeLabel(entry.key),
                            value: entry.value,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _AttributeTile extends StatelessWidget {
  const _AttributeTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.abzioMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.abzioSecondaryText,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E1E1E),
                ),
          ),
        ],
      ),
    );
  }
}
