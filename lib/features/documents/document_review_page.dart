import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import 'documents_api.dart';
import 'review_model.dart';

/// Jenis yang bisa dipilih saat mengisi manual dokumen gagal (api-spec.md bagian 13).
const manualDocTypes = <String, String>{
  'RECEIPT': 'Struk atau kwitansi',
  'SURAT_TUGAS': 'Surat tugas',
  'SPD': 'Surat perjalanan dinas',
};

/// S9: tinjau dan koreksi. Field dengan confidence rendah ditandai.
///
/// Mode [manual] dipakai untuk dokumen yang ekstraksinya gagal (Q-3): pengguna memilih jenis,
/// lalu mengisi kerangka kosong. Semua field tersimpan dengan `source: manual`.
/// Mengembalikan `true` ke layar sebelumnya bila tinjauan berhasil disimpan.
class DocumentReviewPage extends StatefulWidget {
  const DocumentReviewPage({
    super.key,
    required this.api,
    required this.documentId,
    this.manual = false,
  });

  final DocumentsApi api;
  final String documentId;
  final bool manual;

  @override
  State<DocumentReviewPage> createState() => _DocumentReviewPageState();
}

class _DocumentReviewPageState extends State<DocumentReviewPage> {
  Map<String, dynamic> _fields = const {};
  String _docType = '';
  List<ReviewField> _rows = const [];
  final Map<String, TextEditingController> _controllers = {};
  // Isi awal tiap field, untuk tahu apakah pengguna sudah mengubah sesuatu sebelum keluar.
  final Map<String, String> _initialText = {};
  bool _loading = true;
  bool _saving = false;
  String _docRef = '';
  String? _error;
  List<String> _violations = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
  }

  /// Memasang field baru ke layar. Dipakai saat pertama muncul dan saat jenis manual diganti.
  void _apply(Map<String, dynamic> fields, String docType) {
    final rows = flattenReviewFields(fields);
    _disposeControllers();
    _initialText.clear();
    for (final r in rows) {
      final text = reviewInitialText(r.value);
      _initialText[r.path] = text;
      _controllers[r.path] = TextEditingController(text: text);
    }
    setState(() {
      _fields = fields;
      _docType = docType;
      _rows = rows;
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.manual) {
        final fields = await widget.api.template(widget.documentId, _docType.isEmpty ? 'RECEIPT' : _docType);
        _apply(fields, _docType.isEmpty ? 'RECEIPT' : _docType);
      } else {
        final detail = await widget.api.detail(widget.documentId);
        _docRef = detail.summary.docRef;
        final extraction = detail.extraction;
        final fields = (extraction?['fields'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
        final docType = (extraction?['doc_type'] as String?) ?? detail.summary.docType ?? '';
        _apply(fields, docType);
      }
    } on DocumentsApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Tidak ada koneksi. Periksa jaringan lalu coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeManualType(String docType) async {
    setState(() {
      _docType = docType;
      _violations = const [];
      _error = null;
    });
    await _load();
  }

  bool get _dirty => _controllers.entries.any((e) => e.value.text != _initialText[e.key]);

  /// Keluar tanpa menyimpan. Bila ada perubahan belum tersimpan, minta konfirmasi dulu.
  Future<void> _leave() async {
    if (_dirty) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Keluar tanpa menyimpan?'),
          content: const Text('Perubahan yang belum disimpan akan hilang.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Keluar')),
          ],
        ),
      );
      if (leave != true) return;
    }
    if (!mounted) return;
    // Halaman ini bisa dibuka dengan push (dari detail) atau pushReplacement (dari proses).
    if (context.canPop()) {
      context.pop(false);
    } else {
      context.go('/dokumen');
    }
  }

  Future<void> _save() async {
    final edited = {for (final e in _controllers.entries) e.key: e.value.text};
    final fields = buildVerificationFields(_fields, edited);
    setState(() {
      _saving = true;
      _violations = const [];
    });
    try {
      await widget.api.verify(documentId: widget.documentId, docType: _docType, fields: fields);
      if (!mounted) return;
      // go_router: pop lewat context agar route tinjau yang ditutup, bukan halaman di bawahnya (layar kosong).
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/dokumen');
      }
    } on DocumentsApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _violations = e.details;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Tidak ada koneksi. Periksa jaringan lalu coba lagi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.manual ? 'Isi manual${_docRef.isEmpty ? '' : ' $_docRef'}' : 'Tinjau${_docRef.isEmpty ? '' : ' $_docRef'}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Keluar tanpa menyimpan',
          onPressed: _saving ? null : _leave,
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _rows.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_loading && _rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final header = <Widget>[
      if (widget.manual) _manualTypePicker(),
      if (_error != null) _ErrorBox(message: _error!, details: _violations),
    ];
    if (_rows.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ...header,
          const SizedBox(height: 24),
          const Text(
            'Belum ada field untuk diisi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.text),
          ),
        ],
      );
    }

    final needs = countNeedingReview(_rows);
    final children = <Widget>[
      ...header,
      Text(
        widget.manual
            ? 'Isi field yang terbaca di dokumen. Field yang dikosongkan tidak disimpan.'
            : needs == 0
                ? 'Semua field terbaca dengan keyakinan tinggi. Periksa lalu simpan.'
                : '$needs field perlu dicek karena keyakinan OCR rendah.',
        style: const TextStyle(color: AppColors.text, fontSize: 13),
      ),
      const SizedBox(height: 12),
    ];

    String? currentGroup;
    for (final row in _rows) {
      if (row.group != currentGroup) {
        currentGroup = row.group;
        if (row.group.isNotEmpty) {
          children.add(Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              row.group,
              style: const TextStyle(color: AppColors.heading, fontWeight: FontWeight.w600),
            ),
          ));
        }
      }
      children.add(_FieldTile(row: row, controller: _controllers[row.path]!));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: children,
    );
  }

  Widget _manualTypePicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: manualDocTypes.containsKey(_docType) ? _docType : 'RECEIPT',
        decoration: const InputDecoration(labelText: 'Jenis dokumen'),
        items: [
          for (final e in manualDocTypes.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: _saving ? null : (v) => v == null ? null : _changeManualType(v),
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({required this.row, required this.controller});

  final ReviewField row;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: row.needsReview ? AppColors.warning : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(row.label, style: const TextStyle(color: AppColors.heading, fontWeight: FontWeight.w600)),
              ),
              if (row.needsReview) _Badge(text: 'Perlu dicek', color: AppColors.warning, bg: AppColors.warningSurface),
              if (!row.needsReview && row.source == 'manual' && row.value != null)
                const _Badge(text: 'Diubah', color: AppColors.teal, bg: AppColors.tealSurface),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: row.isEmpty ? 'Kosong di dokumen. Isi bila ada.' : null,
            ),
          ),
          if (row.rawText != null && row.rawText != controller.text.trim()) ...[
            const SizedBox(height: 6),
            Text(
              'Dibaca OCR: ${row.rawText}',
              style: const TextStyle(color: AppColors.slate, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color, required this.bg});

  final String text;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Error simpan atau muat. Diberi jarak bawah agar tidak menempel ke field pertama.
class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.details});

  final String message;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppBanner(message: message, details: details),
    );
  }
}
