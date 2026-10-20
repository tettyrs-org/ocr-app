import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import 'documents_api.dart';
import 'processing_page.dart';
import 'upload_category.dart';
import 'upload_method_page.dart';
import 'upload_rules.dart';

/// UUID v4 untuk `Idempotency-Key`. Dibuat sekali per berkas agar percobaan ulang tidak membuat dokumen ganda.
String newIdempotencyKey() {
  final rnd = Random.secure();
  final b = List<int>.generate(16, (_) => rnd.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String hex(int from, int to) => b.sublist(from, to).map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

/// S7: pratinjau berkas lalu unggah. Jenis dokumen mengikuti kategori S4a, tidak dipilih ulang.
class UploadPreviewPage extends StatefulWidget {
  const UploadPreviewPage({super.key, required this.api, required this.file, required this.category, this.replacing});

  final DocumentsApi api;
  final PickedFile file;
  final UploadCategory category;

  /// Dokumen yang berkasnya diganti. Null berarti unggahan dokumen baru.
  final DocumentSummary? replacing;

  @override
  State<UploadPreviewPage> createState() => _UploadPreviewPageState();
}

class _UploadPreviewPageState extends State<UploadPreviewPage> {
  bool _busy = false;
  String? _error;
  List<String> _errorDetails = const [];
  // Kunci disimpan sampai respons diterima, termasuk saat percobaan ulang (design.md 3.1).
  final String _idempotencyKey = newIdempotencyKey();

  Future<void> _upload() async {
    setState(() {
      _busy = true;
      _error = null;
      _errorDetails = const [];
    });
    try {
      final target = widget.replacing;
      final result = target == null
          ? await widget.api.upload(
              bytes: widget.file.bytes,
              filename: widget.file.filename,
              idempotencyKey: _idempotencyKey,
              category: widget.category.apiValue,
              docTypeHint: widget.category.docTypeHint,
            )
          : await widget.api.replace(
              target: target,
              bytes: widget.file.bytes,
              filename: widget.file.filename,
              idempotencyKey: _idempotencyKey,
            );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ProcessingPage(
            api: widget.api,
            documentId: result.documentId,
            docRef: result.docRef,
            pollAfterMs: result.pollAfterMs,
          ),
        ),
      );
    } on DocumentsApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _errorDetails = e.details;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unggahan gagal karena jaringan. Berkas belum dikirim. Tekan Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isImage = UploadRules.detect(widget.file.bytes) != UploadKind.pdf;
    return Scaffold(
      appBar: AppBar(title: const Text('Pratinjau')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(widget.category.icon, size: 18, color: AppColors.slate),
                  const SizedBox(width: 8),
                  Expanded(child: Text(widget.category.title, style: theme.textTheme.bodyMedium)),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  height: 340,
                  child: isImage
                      ? Image.memory(widget.file.bytes, fit: BoxFit.contain)
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.picture_as_pdf_outlined, size: 64, color: AppColors.slate),
                              const SizedBox(height: 8),
                              Text(widget.file.filename, style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.file.filename,
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _busy ? null : _upload,
                  child: Text(_busy ? 'Mengunggah...' : (_error == null ? 'Unggah' : 'Coba lagi')),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AppBanner(message: _error!, details: _errorDetails),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
