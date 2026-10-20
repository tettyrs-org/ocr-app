import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import 'document_status.dart';
import 'document_labels.dart';
import 'document_status_chip.dart';
import 'documents_api.dart';
import 'upload_category.dart';
import 'upload_category_page.dart';
import 'upload_method_page.dart';

/// S2: daftar dokumen milik pengguna. Tombol tambah membuka pilihan unggah (S4).
class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key, required this.api});

  final DocumentsApi api;

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  List<DocumentSummary>? _documents;
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
      final docs = await widget.api.list();
      if (mounted) setState(() => _documents = docs);
    } on DocumentsApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Tidak ada koneksi. Periksa jaringan lalu coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openUpload() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => UploadCategoryPage(api: widget.api)),
    );
    // Setelah kembali, daftar dimuat ulang agar dokumen baru terlihat.
    await _load();
  }

  /// Kategori untuk unggah ulang berkas. Hanya dipakai sebagai konteks halaman, server memakai kategori dokumen.
  UploadCategory _categoryFor(DocumentSummary doc) => switch (doc.docType) {
        'IDENTITY_CARD' => UploadCategory.identity,
        'OTHER' => UploadCategory.other,
        _ => UploadCategory.reimburse,
      };

  Future<void> _replace(DocumentSummary doc) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UploadMethodPage(api: widget.api, category: _categoryFor(doc), replacing: doc),
      ),
    );
    await _load();
  }

  Future<void> _delete(DocumentSummary doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus dokumen?'),
        content: Text('${doc.docRef} akan dihapus dari daftar Anda.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.api.delete(doc.documentId);
      messenger.showSnackBar(const SnackBar(content: Text('Dokumen dihapus.')));
      await _load();
    } on DocumentsApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Tidak ada koneksi. Coba lagi.')));
    }
  }

  void _openDocument(DocumentSummary doc) {
    // Rute tetap dari URL, sehingga reload di detail atau proses kembali ke halaman yang sama.
    if (doc.status == DocumentStatus.processing) {
      context.push('/dokumen/${doc.documentId}/proses?ref=${Uri.encodeQueryComponent(doc.docRef)}');
      return;
    }
    // `go` memastikan URL berubah ke /dokumen/{id}. Tombol kembali di detail kembali ke daftar.
    context.go('/dokumen/${doc.documentId}');
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dokumen')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openUpload,
        icon: const Icon(Icons.add),
        label: const Text('Unggah'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _documents == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // Bungkus dengan ListView agar RefreshIndicator tetap bisa ditarik saat kosong atau gagal.
    if (_error != null && _documents == null) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: AppEmptyState(
              icon: Icons.cloud_off_rounded,
              iconColor: AppColors.error,
              title: 'Dokumen belum bisa dimuat',
              message: _error,
              actionLabel: 'Coba lagi',
              onAction: _load,
            ),
          ),
        ],
      );
    }
    final docs = _documents ?? const [];
    if (docs.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: AppEmptyState(
              icon: Icons.description_outlined,
              title: 'Belum ada dokumen',
              message: 'Tekan Unggah untuk menambahkan dokumen pertama Anda.',
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: docs.length + (_error != null ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        if (_error != null && i == 0) {
          return AppBanner(message: _error!);
        }
        final doc = docs[i - (_error != null ? 1 : 0)];
        return _DocumentCard(
          doc: doc,
          onTap: () => _openDocument(doc),
          onReplace: () => _replace(doc),
          onDelete: () => _delete(doc),
        );
      },
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.doc, required this.onTap, required this.onReplace, required this.onDelete});

  final DocumentSummary doc;
  final VoidCallback onTap;
  final VoidCallback onReplace;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.indigoSurface,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                child: Icon(_iconFor(doc.docType), color: AppColors.indigo),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            doc.docRef,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Aksi dokumen',
                          onSelected: (v) => v == 'replace' ? onReplace() : onDelete(),
                          itemBuilder: (_) => [
                            // Dokumen yang sudah ditinjau dan disimpan final tidak bisa diganti berkasnya.
                            if (doc.status != DocumentStatus.verified)
                              const PopupMenuItem(value: 'replace', child: Text('Ganti berkas')),
                            const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(docTypeLabel(doc.docType), style: theme.textTheme.bodySmall),
                    if (doc.createdAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Diunggah ${formatTanggalUnggah(doc.createdAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.slate),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DocumentStatusChip(status: doc.status),
                        if (doc.fieldsNeedReview > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                              const SizedBox(width: 4),
                              Text(
                                '${doc.fieldsNeedReview} field perlu ditinjau',
                                style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(String? docType) => switch (docType) {
        'IDENTITY_CARD' => Icons.badge_outlined,
        'SURAT_TUGAS' || 'SPD' => Icons.assignment_outlined,
        'REIMBURSEMENT_FUEL' => Icons.local_gas_station_outlined,
        'PARKING_CARD' => Icons.local_parking_outlined,
        'RECEIPT' => Icons.receipt_long_outlined,
        _ => Icons.description_outlined,
      };
}
