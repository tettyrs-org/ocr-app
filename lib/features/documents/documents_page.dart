import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import 'document_status.dart';
import 'document_labels.dart';
import '../../auth/demo_mode.dart';
import 'document_status_chip.dart';
import 'documents_api.dart';
import 'upload_category.dart';
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
  // Dokumen yang dipilih untuk dihapus sekaligus. Mode pilih aktif bila tidak kosong.
  final Set<String> _terpilih = {};
  // Mode pilih diaktifkan lewat tombol di AppBar. Setelah aktif, lingkaran pilih tampil di setiap kartu.
  bool _modePilih = false;

  bool get _memilih => _modePilih || _terpilih.isNotEmpty;

  void _keluarModePilih() {
    setState(() {
      _terpilih.clear();
      _modePilih = false;
    });
  }

  void _toggle(String documentId) {
    setState(() {
      if (!_terpilih.remove(documentId)) _terpilih.add(documentId);
    });
  }

  /// Notifikasi di atas tombol Unggah, supaya tidak menutupinya.
  void _pesan(ScaffoldMessengerState messenger, String teks) {
    messenger.showSnackBar(SnackBar(
      content: Text(teks),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
    ));
  }

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
      MaterialPageRoute<void>(
        builder: (_) => UploadMethodPage(api: widget.api, category: UploadCategory.auto),
      ),
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
      _pesan(messenger, 'Dokumen dihapus.');
      await _load();
    } on DocumentsApiException catch (e) {
      _pesan(messenger, e.message);
    } catch (_) {
      _pesan(messenger, 'Tidak ada koneksi. Coba lagi.');
    }
  }

  Future<void> _hapusTerpilih() async {
    final jumlah = _terpilih.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus $jumlah dokumen?'),
        content: const Text('Dokumen yang dipilih akan dihapus dari daftar Anda.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    var gagal = 0;
    // Satu per satu, supaya kegagalan satu dokumen tidak membatalkan yang lain.
    for (final id in _terpilih.toList()) {
      try {
        await widget.api.delete(id);
      } catch (_) {
        gagal++;
      }
    }
    if (!mounted) return;
    setState(() {
      _terpilih.clear();
      _modePilih = false;
    });
    await _load();
    _pesan(messenger, gagal == 0 ? '$jumlah dokumen dihapus.' : '${jumlah - gagal} dihapus, $gagal gagal.');
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
    final docs = _documents ?? const <DocumentSummary>[];
    return Scaffold(
      appBar: AppBar(
        leading: _memilih
            ? IconButton(
                tooltip: 'Batal pilih',
                icon: const Icon(Icons.close),
                onPressed: _keluarModePilih,
              )
            : null,
        title: Text(_memilih
            ? (_terpilih.isEmpty ? 'Pilih dokumen' : '${_terpilih.length} dipilih')
            : 'Dokumen'),
        actions: _memilih
            ? [
                IconButton(
                  tooltip: 'Pilih semua',
                  icon: const Icon(Icons.select_all),
                  onPressed: docs.isEmpty
                      ? null
                      : () => setState(() => _terpilih.addAll(docs.map((d) => d.documentId))),
                ),
                IconButton(
                  tooltip: 'Hapus yang dipilih',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _terpilih.isEmpty ? null : _hapusTerpilih,
                ),
              ]
            : [
                if (!DemoMode.active)
                  IconButton(
                  tooltip: 'Pilih dokumen',
                  icon: const Icon(Icons.checklist),
                  onPressed: docs.isEmpty ? null : () => setState(() => _modePilih = true),
                ),
              ],
      ),
      floatingActionButton: _memilih
          ? null
          : FloatingActionButton.extended(
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
    // Ringkasan di atas daftar, lalu baris datar dengan pemisah tipis (bukan kartu terpisah).
    final adaRingkasan = docs.isNotEmpty ? 1 : 0;
    final adaBanner = _error != null ? 1 : 0;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
      itemCount: adaRingkasan + adaBanner + docs.length,
      separatorBuilder: (_, i) => i < adaRingkasan
          ? const SizedBox(height: 8)
          : const Divider(height: 1, indent: 74),
      itemBuilder: (context, i) {
        if (adaRingkasan == 1 && i == 0) {
          return _RingkasanDokumen(docs: docs);
        }
        final j = i - adaRingkasan;
        if (adaBanner == 1 && j == 0) {
          return AppBanner(message: _error!);
        }
        final doc = docs[j - adaBanner];
        return _FadeIn(
          child: _DocumentCard(
            doc: doc,
            memilih: _memilih,
            terpilih: _terpilih.contains(doc.documentId),
            onTap: () => _memilih ? _toggle(doc.documentId) : _openDocument(doc),
            // Mode demo tidak mendukung hapus, jadi tahan-untuk-pilih juga dinonaktifkan.
            onLongPress: DemoMode.active ? () {} : () => _toggle(doc.documentId),
            onReplace: () => _replace(doc),
            onDelete: () => _delete(doc),
          ),
        );
      },
    );
  }
}

/// Jumlah dokumen dan yang masih perlu ditinjau, di atas daftar.
class _RingkasanDokumen extends StatelessWidget {
  const _RingkasanDokumen({required this.docs});

  final List<DocumentSummary> docs;

  @override
  Widget build(BuildContext context) {
    final perlu = docs.where((d) => d.status == DocumentStatus.extracted).length;
    final tema = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          _statistik('${docs.length}', 'dokumen', AppColors.heading, tema),
          const SizedBox(width: 28),
          _statistik('$perlu', DemoMode.active ? 'hasil demo' : 'perlu ditinjau', AppColors.indigo, tema),
        ],
      ),
    );
  }

  Widget _statistik(String nilai, String label, Color warna, TextTheme tema) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nilai, style: tema.headlineSmall?.copyWith(color: warna)),
        Text(label, style: tema.bodySmall),
      ],
    );
  }
}

/// Muncul pelan saat pertama tampil, supaya daftar terasa hidup tanpa mengganggu.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: child,
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.doc,
    required this.onTap,
    required this.onLongPress,
    required this.onReplace,
    required this.onDelete,
    this.memilih = false,
    this.terpilih = false,
  });

  final DocumentSummary doc;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onReplace;
  final VoidCallback onDelete;
  // `memilih`: mode pilih aktif. `terpilih`: kartu ini dipilih.
  final bool memilih;
  final bool terpilih;

  // Warna sama dengan chip status (document_status_chip.dart), supaya ikon dan label tidak bertentangan.
  static Color _warnaStatus(DocumentStatus s) => switch (s) {
        DocumentStatus.processing => AppColors.slate,
        DocumentStatus.extracted => AppColors.indigo,
        DocumentStatus.verified => AppColors.teal,
        DocumentStatus.extractionFailed => AppColors.error,
        DocumentStatus.unknown => AppColors.slate,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: terpilih ? AppColors.indigoSurface : AppColors.background,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (memilih)
                Padding(
                  padding: const EdgeInsets.only(right: 4, top: 6),
                  child: Icon(
                    terpilih ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: terpilih ? AppColors.indigo : AppColors.slate,
                  ),
                ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _warnaStatus(doc.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                child: Icon(_iconFor(doc.docType), color: _warnaStatus(doc.status)),
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
                        // Mode demo tidak menyimpan perubahan, jadi aksi ganti dan hapus disembunyikan.
                        if (!DemoMode.active)
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
