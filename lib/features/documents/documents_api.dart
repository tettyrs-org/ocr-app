import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/bff_service.dart';
import 'document_status.dart';

/// Kesalahan dari BFF/API, dibaca dari envelope `error.code` (api-spec bagian 1).
class DocumentsApiException implements Exception {
  DocumentsApiException(this.code, this.message, {this.details = const []});
  final String code;
  final String message;

  /// Pelanggaran validasi per field (VALIDATION_ERROR), dibaca dari `error.details`.
  final List<String> details;

  @override
  String toString() => message;
}

class DocumentSummary {
  DocumentSummary({
    required this.documentId,
    required this.docRef,
    required this.docType,
    required this.status,
    required this.createdAt,
    required this.fieldsNeedReview,
  });

  final String documentId;
  final String docRef;
  final String? docType;
  final DocumentStatus status;
  final DateTime? createdAt;
  final int fieldsNeedReview;

  factory DocumentSummary.fromJson(Map<String, dynamic> j) {
    final summary = (j['summary'] as Map<String, dynamic>?) ?? const {};
    return DocumentSummary(
      documentId: j['document_id'] as String,
      docRef: j['doc_ref'] as String,
      docType: j['doc_type'] as String?,
      status: documentStatusFromApi(j['status'] as String?),
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
      fieldsNeedReview: (summary['fields_need_review'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Detail satu dokumen (api-spec bagian 4). `extraction` null untuk identitas (ditahan, OQ-8).
class DocumentDetail {
  DocumentDetail({
    required this.summary,
    required this.mimeType,
    required this.sizeBytes,
    required this.fileAvailable,
    required this.extraction,
    required this.verification,
  });

  final DocumentSummary summary;
  final String? mimeType;
  final int? sizeBytes;
  final bool fileAvailable;
  final Map<String, dynamic>? extraction;
  final Map<String, dynamic>? verification;

  factory DocumentDetail.fromJson(Map<String, dynamic> j) {
    final file = (j['file'] as Map<String, dynamic>?) ?? const {};
    return DocumentDetail(
      summary: DocumentSummary.fromJson(j),
      mimeType: file['mime_type'] as String?,
      sizeBytes: (file['size_bytes'] as num?)?.toInt(),
      fileAvailable: file['available'] as bool? ?? false,
      extraction: j['extraction'] as Map<String, dynamic>?,
      verification: j['verification'] as Map<String, dynamic>?,
    );
  }
}

class UploadResult {
  UploadResult({required this.documentId, required this.docRef, required this.status, required this.pollAfterMs});

  final String documentId;
  final String docRef;
  final DocumentStatus status;
  final int pollAfterMs;
}

class DocumentStatusResult {
  DocumentStatusResult({required this.status});
  final DocumentStatus status;
}

class DocumentsApi {
  DocumentsApi(this._bff);

  final BffService _bff;

  /// Daftar dokumen milik pengguna, terbaru dulu (api-spec bagian 3).
  Future<List<DocumentSummary>> list({int page = 1, int limit = 20}) async {
    final res = await _bff.apiGet('/v1/documents?page=$page&limit=$limit');
    final body = _decode(res);
    final data = (body['data'] as List).cast<Map<String, dynamic>>();
    return data.map(DocumentSummary.fromJson).toList();
  }

  /// Detail satu dokumen (api-spec bagian 4).
  Future<DocumentDetail> detail(String documentId) async {
    final res = await _bff.apiGet('/v1/documents/$documentId');
    final data = _decode(res)['data'] as Map<String, dynamic>;
    return DocumentDetail.fromJson(data);
  }

  /// Kerangka field kosong untuk isi manual dokumen gagal (api-spec.md bagian 13).
  Future<Map<String, dynamic>> template(String documentId, String docType) async {
    final res = await _bff.apiGet('/v1/documents/$documentId/template?doc_type=$docType');
    final data = _decode(res)['data'] as Map<String, dynamic>;
    return (data['fields'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
  }

  /// Simpan hasil tinjau (api-spec bagian 5). `fields` berisi seluruh kumpulan, bukan hanya yang diubah.
  Future<void> verify({
    required String documentId,
    required String docType,
    required Map<String, dynamic> fields,
  }) async {
    final res = await _bff.apiWrite(
      'PUT',
      '/v1/documents/$documentId/verification',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'schema_version': '1.0', 'doc_type': docType, 'fields': fields}),
    );
    _decode(res);
  }

  /// Status satu dokumen untuk polling (api-spec bagian 4).
  Future<DocumentStatusResult> status(String documentId) async {
    final res = await _bff.apiGet('/v1/documents/$documentId');
    final data = _decode(res)['data'] as Map<String, dynamic>;
    return DocumentStatusResult(status: documentStatusFromApi(data['status'] as String?));
  }

  /// Unggah berkas. `idempotencyKey` disimpan oleh pemanggil sampai respons diterima (design.md 3.1).
  Future<UploadResult> upload({
    required List<int> bytes,
    required String filename,
    required String idempotencyKey,
    required String category,
    String? docTypeHint,
  }) async {
    final res = await _bff.apiUpload(
      '/v1/documents',
      bytes: bytes,
      filename: filename,
      idempotencyKey: idempotencyKey,
      fields: {'category': category, 'doc_type_hint': ?docTypeHint},
    );
    final data = _decode(res)['data'] as Map<String, dynamic>;
    return UploadResult(
      documentId: data['document_id'] as String,
      docRef: data['doc_ref'] as String,
      status: documentStatusFromApi(data['status'] as String?),
      pollAfterMs: (data['poll_after_ms'] as num?)?.toInt() ?? 2000,
    );
  }

  /// Ganti berkas dokumen yang belum final. Hasil ekstraksi lama dibuang dan dokumen diproses ulang di server.
  Future<UploadResult> replace({
    required DocumentSummary target,
    required List<int> bytes,
    required String filename,
    required String idempotencyKey,
  }) async {
    final res = await _bff.apiUpload(
      '/v1/documents/${target.documentId}/upload',
      bytes: bytes,
      filename: filename,
      idempotencyKey: idempotencyKey,
    );
    _decode(res);
    return UploadResult(
      documentId: target.documentId,
      docRef: target.docRef,
      status: DocumentStatus.processing,
      pollAfterMs: 2000,
    );
  }

  /// Hapus dokumen milik pengguna. Di server ini penghapusan lunak: dokumen hilang dari daftar.
  Future<void> delete(String documentId) async {
    final res = await _bff.apiWrite('DELETE', '/v1/documents/$documentId');
    _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    final body = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      final err = body['error'] as Map<String, dynamic>?;
      throw DocumentsApiException(
        err?['code'] as String? ?? 'HTTP_${res.statusCode}',
        _messageFor(err?['code'] as String?, res.statusCode),
        details: _detailMessages(err?['details']),
      );
    }
    return body;
  }

  static List<String> _detailMessages(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final d in raw)
        if (d is Map) '${d['field'] ?? ''}: ${d['message'] ?? ''}'.replaceFirst(RegExp(r'^: '), ''),
    ];
  }

  /// Pesan untuk pengguna dibuat dari kode error, bukan dari teks server (api-spec bagian 1).
  String _messageFor(String? code, int status) {
    return switch (code) {
      'UNSUPPORTED_MEDIA_TYPE' => 'Format berkas tidak didukung. Gunakan JPG, PNG, atau PDF.',
      'PAGE_LIMIT_EXCEEDED' => 'PDF memiliki lebih dari 15 halaman. Pisahkan berkas lalu unggah satu per satu.',
      'FILE_TOO_LARGE' => 'Ukuran berkas terlalu besar.',
      'UNAUTHENTICATED' => 'Sesi habis. Masuk lagi untuk melanjutkan.',
      'FORBIDDEN' => 'Anda tidak punya izin untuk tindakan ini.',
      'DOC_TYPE_NOT_SUPPORTED' => 'Jenis dokumen ini belum didukung.',
      'QUALITY_REJECTED' => 'Foto belum dapat dibaca. Silakan foto ulang dengan memperhatikan saran berikut.',
      'ALREADY_VERIFIED' => 'Dokumen ini sudah ditinjau sebelumnya.',
      'EXTRACTION_IN_PROGRESS' => 'Dokumen masih diproses. Tinjau setelah selesai.',
      'EXTRACTION_FAILED_NOT_EDITABLE' => 'Ekstraksi dokumen ini gagal, jadi belum bisa ditinjau. Hubungi admin untuk memproses ulang.',
      'CONFLICT' => 'Dokumen ini tidak memiliki field untuk ditinjau.',
      'VALIDATION_ERROR' => 'Ada isian yang belum valid. Periksa daftar di bawah.',
      _ => status >= 500
          ? 'Server sedang bermasalah. Coba lagi beberapa saat.'
          : 'Permintaan gagal. Coba lagi.',
    };
  }
}
