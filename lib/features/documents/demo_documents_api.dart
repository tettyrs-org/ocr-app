import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../../auth/bff_service.dart';
import '../../auth/demo_mode.dart';
import 'document_status.dart';
import 'documents_api.dart';

/// Hasil ekstraksi dari unggahan demo, disimpan di memori. Hilang saat halaman dimuat ulang.
/// Tidak ada yang ditulis ke database: ekstraksi dijalankan oleh ms-ocr tanpa penyimpanan.
final _unggahanDemo = <DocumentSummary>[];
final _hasilDemo = <String, Map<String, dynamic>>{};

const _pesanDemo = 'Mode demo: perubahan tidak disimpan.';

/// Membaca aliran NDJSON dari ms-ocr. Setiap baris tahap dikirim ke `onTahap`. Baris galat dilempar sebagai
/// DocumentsApiException. Mengembalikan hasil ekstraksi, atau null bila aliran berakhir tanpa hasil.
Future<Map<String, dynamic>?> _bacaAliranDemo(
  Stream<List<int>> aliran,
  void Function(String tahap)? onTahap,
) async {
  Map<String, dynamic>? hasil;
  await for (final baris in aliran.transform(utf8.decoder).transform(const LineSplitter())) {
    if (baris.trim().isEmpty) continue;
    final obj = jsonDecode(baris) as Map<String, dynamic>;
    if (obj.containsKey('tahap')) {
      onTahap?.call(obj['tahap'] as String);
    } else if (obj.containsKey('hasil')) {
      hasil = obj['hasil'] as Map<String, dynamic>;
    } else if (obj.containsKey('galat')) {
      throw DocumentsApiException(
        obj['galat'] as String,
        'Berkas tidak dapat dibaca. Coba foto atau pindai ulang.',
      );
    }
  }
  return hasil;
}

DocumentSummary _cari(String documentId) {
  for (final d in _unggahanDemo) {
    if (d.documentId == documentId) return d;
  }
  throw DocumentsApiException('NOT_FOUND', 'Dokumen demo tidak ditemukan.');
}

/// Sama seperti DocumentsApi, tetapi di mode demo semua panggilan dijawab dari memori.
/// Unggahan dikirim ke /bff/demo/extract (BFF -> ms-ocr), tanpa login dan tanpa database.
class DemoAwareDocumentsApi extends DocumentsApi {
  DemoAwareDocumentsApi(this._bffDemo) : super(_bffDemo);

  final BffService _bffDemo;

  @override
  Future<List<DocumentSummary>> list({int page = 1, int limit = 20}) {
    if (!DemoMode.active) return super.list(page: page, limit: limit);
    return Future.value(List.of(_unggahanDemo));
  }

  @override
  Future<DocumentDetail> detail(String documentId) {
    if (!DemoMode.active) return super.detail(documentId);
    final extraction = _hasilDemo[documentId];
    return Future.value(DocumentDetail(
      summary: _cari(documentId),
      mimeType: null,
      sizeBytes: null,
      fileAvailable: false,
      extraction: extraction,
      verification: null,
    ));
  }

  @override
  Future<Map<String, dynamic>> template(String documentId, String docType) {
    if (!DemoMode.active) return super.template(documentId, docType);
    return Future.value(const <String, dynamic>{});
  }

  @override
  Future<void> verify({
    required String documentId,
    required String docType,
    required Map<String, dynamic> fields,
  }) {
    if (!DemoMode.active) return super.verify(documentId: documentId, docType: docType, fields: fields);
    return Future.error(DocumentsApiException('DEMO', _pesanDemo));
  }

  @override
  Future<DocumentStatusResult> status(String documentId) {
    if (!DemoMode.active) return super.status(documentId);
    return Future.value(DocumentStatusResult(status: _cari(documentId).status));
  }

  @override
  Future<UploadResult> upload({
    required List<int> bytes,
    required String filename,
    required String idempotencyKey,
    required String category,
    String? docTypeHint,
    void Function(String tahap)? onTahap,
  }) async {
    if (!DemoMode.active) {
      return super.upload(
        bytes: bytes,
        filename: filename,
        idempotencyKey: idempotencyKey,
        category: category,
        docTypeHint: docTypeHint,
      );
    }
    final res = await _bffDemo.demoExtract(bytes, category);
    if (res.statusCode >= 400) {
      final body = await res.stream.bytesToString();
      final json = body.isEmpty ? const <String, dynamic>{} : jsonDecode(body) as Map<String, dynamic>;
      final err = json['error'] as Map<String, dynamic>?;
      throw DocumentsApiException(
        err?['code'] as String? ?? 'HTTP_${res.statusCode}',
        err?['message'] as String? ?? 'Ekstraksi demo gagal. Coba lagi.',
      );
    }
    final extraction = await _bacaAliranDemo(res.stream, onTahap);
    if (extraction == null) {
      throw DocumentsApiException('OCR_FAILED', 'Berkas tidak dapat dibaca. Coba foto atau pindai ulang.');
    }
    final id = 'demo-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 20)}';
    final ref = 'DEMO-${(_unggahanDemo.length + 1).toString().padLeft(4, '0')}';
    _hasilDemo[id] = extraction;
    _unggahanDemo.insert(
      0,
      DocumentSummary(
        documentId: id,
        docRef: ref,
        docType: extraction['doc_type'] as String?,
        status: DocumentStatus.extracted,
        createdAt: DateTime.now(),
        fieldsNeedReview: 0,
      ),
    );
    return UploadResult(documentId: id, docRef: ref, status: DocumentStatus.extracted, pollAfterMs: 2000);
  }

  @override
  Future<UploadResult> replace({
    required DocumentSummary target,
    required List<int> bytes,
    required String filename,
    required String idempotencyKey,
  }) {
    if (!DemoMode.active) {
      return super.replace(target: target, bytes: bytes, filename: filename, idempotencyKey: idempotencyKey);
    }
    return Future.error(DocumentsApiException('DEMO', _pesanDemo));
  }

  @override
  Future<void> delete(String documentId) {
    if (!DemoMode.active) return super.delete(documentId);
    return Future.error(DocumentsApiException('DEMO', _pesanDemo));
  }
}
