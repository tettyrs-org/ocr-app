import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import 'document_labels.dart';
import 'document_status.dart';
import 'document_status_chip.dart';
import 'documents_api.dart';
import 'review_model.dart';


/// S3: detail dokumen. Menampilkan status, berkas, hasil ekstraksi, dan tinjauan.
/// Data identitas (KTP) ditampilkan kepada pemiliknya dalam bentuk sudah didekripsi (api-spec.md bagian 14).
class DocumentDetailPage extends StatefulWidget {
  const DocumentDetailPage({super.key, required this.api, required this.documentId});

  final DocumentsApi api;
  final String documentId;

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  DocumentDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.api.detail(widget.documentId);
      if (mounted) setState(() => _detail = detail);
    } on DocumentsApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Tidak ada koneksi. Periksa jaringan lalu coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_detail?.summary.docRef ?? 'Dokumen'),
        leading: BackButton(onPressed: _back),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  /// Dibuka dengan `go`, jadi tidak selalu ada halaman sebelumnya untuk di-pop.
  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dokumen');
    }
  }

  Widget _buildBody() {
    if (_loading && _detail == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final detail = _detail;
    if (detail == null) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: AppEmptyState(
              icon: Icons.cloud_off_rounded,
              iconColor: AppColors.error,
              title: 'Dokumen tidak dapat dimuat',
              message: _error,
              actionLabel: 'Coba lagi',
              onAction: _load,
            ),
          ),
        ],
      );
    }
    final s = detail.summary;
    final identity = s.docType == 'IDENTITY_CARD';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      docTypeLabel(s.docType),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.heading),
                    ),
                  ),
                  DocumentStatusChip(status: s.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(_createdText(s.createdAt), style: const TextStyle(color: AppColors.slate, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          title: 'Berkas',
          child: Text(
            detail.fileAvailable
                ? '${_mimeText(detail.mimeType)}${_sizeText(detail.sizeBytes)}'
                : 'Berkas sudah dihapus setelah verifikasi.',
            style: const TextStyle(color: AppColors.text),
          ),
        ),
        const SizedBox(height: 12),
        if (detail.extraction != null)
          _FieldsCard(
            title: identity ? 'Data identitas' : 'Hasil ekstraksi',
            extraction: detail.extraction!,
          )
        else
          _Card(
            title: 'Hasil ekstraksi',
            child: Text(_extractionText(detail), style: const TextStyle(color: AppColors.text)),
          ),
        if (detail.verification != null) ...[
          const SizedBox(height: 12),
          _Card(
            title: 'Tinjauan',
            child: Text(
              // Nama peninjau, bukan UID. Dokumen lama yang belum punya nama tampil sebagai "Peninjau".
              'Sudah ditinjau oleh ${detail.verification!['verified_by_name'] ?? 'Peninjau'}.',
              style: const TextStyle(color: AppColors.text),
            ),
          ),
        ],
        // KTP juga ditinjau pemiliknya: field dari OCR bisa salah baca dan harus bisa dikoreksi.
        ...[
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _canReview(detail) ? () => _openReview(detail, manual: false) : null,
              child: Text(detail.verification == null ? 'Tinjau dan koreksi' : 'Sudah ditinjau'),
            ),
          ),
          if (_canManual(detail)) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => _openReview(detail, manual: true),
                child: const Text('Isi manual'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _reviewHint(detail),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.slate, fontSize: 12),
          ),
        ],
      ],
    );
  }

  /// Tinjauan tersedia bila ekstraksi sudah menghasilkan field dan dokumen belum diverifikasi.
  bool _canReview(DocumentDetail d) {
    final fields = d.extraction?['fields'];
    return d.verification == null && fields is Map && fields.isNotEmpty;
  }

  /// Isi manual (Q-3): untuk dokumen yang ekstraksinya gagal dan belum diverifikasi.
  bool _canManual(DocumentDetail d) {
    return d.verification == null && d.summary.status == DocumentStatus.extractionFailed;
  }

  Future<void> _openReview(DocumentDetail d, {required bool manual}) async {
    final saved = await context.push<bool>(
      '/dokumen/${widget.documentId}/tinjau${manual ? '?manual=1' : ''}',
    );
    if (saved == true && mounted) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tinjauan tersimpan.')),
        );
      }
    }
  }

  String _extractionText(DocumentDetail d) {
    if (d.extraction != null) return 'Field sudah diekstraksi.';
    if (d.summary.status == DocumentStatus.processing) return 'Dokumen masih diproses.';
    if (d.summary.status == DocumentStatus.extractionFailed) {
      return 'Ekstraksi gagal. Anda bisa mengisi datanya secara manual.';
    }
    return 'Belum ada field hasil ekstraksi.';
  }

  String _reviewHint(DocumentDetail d) {
    if (d.verification != null) return 'Dokumen sudah ditinjau dan tidak dapat diubah lagi.';
    if (_canReview(d)) return 'Periksa setiap field. Field yang ditandai perlu dicek lebih dulu.';
    return 'Tinjau dan koreksi tersedia setelah field hasil ekstraksi dibuat.';
  }

  String _mimeText(String? mime) => switch (mime) {
        'application/pdf' => 'PDF',
        'image/png' => 'Gambar PNG',
        'image/jpeg' => 'Gambar JPG',
        _ => 'Berkas',
      };

  String _sizeText(int? bytes) {
    if (bytes == null) return '';
    final kb = bytes / 1024;
    return kb >= 1024 ? ' · ${(kb / 1024).toStringAsFixed(1)} MB' : ' · ${kb.round()} KB';
  }

  String _createdText(DateTime? t) {
    if (t == null) return '';
    final l = keJakarta(t);
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Diunggah ${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)} WIB';
  }
}

/// Field hasil ekstraksi. Data KTP sudah didekripsi oleh API untuk pemiliknya; hanya ditampilkan di sini, tidak dicatat.
class _FieldsCard extends StatelessWidget {
  const _FieldsCard({required this.title, required this.extraction});

  final String title;
  final Map<String, dynamic> extraction;

  @override
  Widget build(BuildContext context) {
    final fields = extraction['fields'];
    final rows = fields is Map<String, dynamic> ? flattenReviewFields(fields) : const <ReviewField>[];
    return _Card(
      title: title,
      child: rows.isEmpty
          ? const Text('Tidak ada data yang terbaca.', style: TextStyle(color: AppColors.text))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: AppKeyValue(label: r.label, value: r.value?.toString() ?? '-'),
                  ),
              ],
            ),
    );
  }
}

/// Kartu bagian detail. Judul opsional, isi mengikuti [AppCard].
class _Card extends StatelessWidget {
  const _Card({this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) => AppCard(title: title, child: child);
}
