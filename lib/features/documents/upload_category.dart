import 'package:flutter/material.dart';

/// Kategori unggahan (S4a). Menentukan `category` yang dikirim ke server dan `doc_type_hint` bila pasti.
enum UploadCategory {
  identity(
    apiValue: 'identity',
    title: 'Identitas diri',
    description: 'KTP dan kartu identitas lainnya',
    icon: Icons.badge_outlined,
    docTypeHint: 'IDENTITY_CARD',
  ),
  reimburse(
    apiValue: 'reimburse',
    title: 'Dokumen reimburse',
    description: 'Bensin, parkir, kwitansi, dan nota kantor. Jenis dikenali otomatis',
    icon: Icons.receipt_long_outlined,
    docTypeHint: null,
  ),
  other(
    apiValue: 'other',
    title: 'Dokumen lainnya',
    description: 'Berkas lain. Teks dibaca dan diringkas tanpa isian terstruktur',
    icon: Icons.description_outlined,
    docTypeHint: 'OTHER',
  );

  const UploadCategory({
    required this.apiValue,
    required this.title,
    required this.description,
    required this.icon,
    required this.docTypeHint,
  });

  final String apiValue;
  final String title;
  final String description;
  final IconData icon;
  final String? docTypeHint;
}
