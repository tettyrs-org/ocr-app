import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'document_status.dart';

class DocumentStatusChip extends StatelessWidget {
  const DocumentStatusChip({super.key, required this.status});

  final DocumentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _presentation(status);
    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
    );
  }

  static (String, Color) _presentation(DocumentStatus status) {
    return switch (status) {
      DocumentStatus.processing => ('Sedang diproses', AppColors.slate),
      DocumentStatus.extracted => ('Perlu ditinjau', AppColors.indigo),
      DocumentStatus.verified => ('Tersimpan', AppColors.teal),
      DocumentStatus.extractionFailed => ('Gagal', AppColors.error),
      DocumentStatus.unknown => ('Status tidak dikenal', AppColors.slate),
    };
  }
}
