import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'documents_api.dart';
import 'upload_category.dart';
import 'upload_method_page.dart';

/// S4a: pilih kategori unggahan. Setelah dipilih, lanjut ke pilihan metode (S4).
class UploadCategoryPage extends StatelessWidget {
  const UploadCategoryPage({super.key, required this.api});

  final DocumentsApi api;

  void _select(BuildContext context, UploadCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UploadMethodPage(api: api, category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Unggah dokumen')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Pilih jenis dokumen yang akan diunggah.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            for (final category in UploadCategory.values) ...[
              _CategoryCard(category: category, onTap: () => _select(context, category)),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});

  final UploadCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '${category.title}. ${category.description}',
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(category.icon, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category.title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(category.description, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
