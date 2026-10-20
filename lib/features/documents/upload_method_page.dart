import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_theme.dart';
import 'documents_api.dart';
import 'upload_category.dart';
import 'upload_preview_page.dart';
import 'upload_rules.dart';
import 'web_camera_page.dart';
import 'web_file_input.dart';

/// Berkas yang sudah dipilih dan lolos validasi awal.
class PickedFile {
  PickedFile({required this.bytes, required this.filename});
  final Uint8List bytes;
  final String filename;
}

/// S4: pilih metode unggah (foto atau berkas) untuk kategori yang sudah dipilih di S4a.
class UploadMethodPage extends StatelessWidget {
  const UploadMethodPage({super.key, required this.api, required this.category, this.replacing});

  final DocumentsApi api;
  final UploadCategory category;

  /// Bila diisi, berkas yang dipilih menggantikan dokumen ini, bukan membuat dokumen baru.
  final DocumentSummary? replacing;

  Future<void> _take(BuildContext context, PickedFile file) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UploadPreviewPage(api: api, file: file, category: category, replacing: replacing),
      ),
    );
  }

  Future<void> _fromCamera(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (kIsWeb) {
      // S5 di web: kamera dalam aplikasi (live preview), bukan pemilih berkas.
      final bytes = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute<Uint8List>(builder: (_) => const WebCameraPage()),
      );
      if (bytes == null || !context.mounted) return;
      final error = UploadRules.validate(bytes);
      if (error != null) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      await _take(context, PickedFile(bytes: bytes, filename: 'foto.jpg'));
      return;
    }
    try {
      final photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 92);
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      final error = UploadRules.validate(bytes);
      if (error != null) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      if (context.mounted) {
        await _take(context, PickedFile(bytes: bytes, filename: photo.name.isEmpty ? 'foto.jpg' : photo.name));
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Kamera tidak dapat dibuka. Periksa izin kamera.')));
    }
  }

  /// Jalur web: input file browser. Validasi dan navigasi sama dengan jalur perangkat.
  Future<void> _pickOnWeb(
    BuildContext context, {
    required String accept,
    required String fallbackName,
    bool preferCamera = false,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await pickWithBrowserInput(accept: accept, preferCamera: preferCamera);
      if (picked == null) return;
      final error = UploadRules.validate(picked.bytes);
      if (error != null) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      if (context.mounted) {
        await _take(context, PickedFile(bytes: picked.bytes, filename: picked.name.isEmpty ? fallbackName : picked.name));
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Berkas tidak dapat dipilih. Coba lagi.')));
    }
  }

  Future<void> _fromFile(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (kIsWeb) {
      await _pickOnWeb(
        context,
        accept: '.jpg,.jpeg,.png,.pdf,image/jpeg,image/png,application/pdf',
        fallbackName: 'berkas',
      );
      return;
    }
    try {
      await _fromFileNative(context, messenger);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Berkas tidak dapat dipilih. Coba lagi.')));
    }
  }

  Future<void> _fromFileNative(BuildContext context, ScaffoldMessengerState messenger) async {
    const documentType = XTypeGroup(
      label: 'Dokumen',
      extensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    final file = await openFile(acceptedTypeGroups: const [documentType]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final error = UploadRules.validate(bytes);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (context.mounted) {
      await _take(context, PickedFile(bytes: bytes, filename: file.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(category.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(category.description, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 20),
              _MethodTile(
                icon: Icons.photo_camera_outlined,
                label: 'Ambil foto',
                hint: 'Foto dokumen dengan kamera perangkat',
                onPressed: () => _fromCamera(context),
              ),
              const SizedBox(height: 12),
              _MethodTile(
                icon: Icons.upload_file_outlined,
                label: 'Pilih berkas',
                hint: 'JPG, PNG, atau PDF dari perangkat',
                onPressed: () => _fromFile(context),
              ),
              const Spacer(),
              Text(
                'Format: ${UploadRules.acceptedFormatsLabel}. '
                'Gambar maksimal 10 MB. PDF maksimal 25 MB dan 15 halaman.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({required this.icon, required this.label, required this.hint, required this.onPressed});

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '$label. $hint',
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(hint, style: theme.textTheme.bodySmall),
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
