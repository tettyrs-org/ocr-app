import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_app/auth/bff_service.dart';
import 'package:ocr_app/features/documents/document_detail_page.dart';
import 'package:ocr_app/features/documents/document_status.dart';
import 'package:ocr_app/features/documents/documents_api.dart';

/// Tiruan BFF yang tidak dipakai: DocumentsApi hanya dipanggil lewat detail() yang di-override di bawah.
class _NoBff implements BffService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeApi extends DocumentsApi {
  _FakeApi(this._detail) : super(_NoBff());

  final DocumentDetail _detail;

  @override
  Future<DocumentDetail> detail(String documentId) async => _detail;
}

DocumentDetail _detail({
  Map<String, dynamic>? extraction,
  Map<String, dynamic>? verification,
  DocumentStatus status = DocumentStatus.extracted,
}) {
  return DocumentDetail(
    summary: DocumentSummary(
      documentId: 'doc-1',
      docRef: 'DOC-12345678',
      docType: 'RECEIPT',
      status: status,
      createdAt: DateTime(2026, 10, 16, 21, 59),
      fieldsNeedReview: 0,
    ),
    mimeType: 'image/jpeg',
    sizeBytes: 182000,
    fileAvailable: true,
    extraction: extraction,
    verification: verification,
  );
}

Future<void> _pump(WidgetTester tester, DocumentDetail detail) async {
  await tester.pumpWidget(MaterialApp(
    home: DocumentDetailPage(api: _FakeApi(detail), documentId: 'doc-1'),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hasil ekstraksi tampil sebagai form dengan label dan nilai', (tester) async {
    await _pump(tester, _detail(extraction: {
      'schema_version': '1.0',
      'doc_type': 'RECEIPT',
      'fields': {
        'nominal_total': {'value': 600000, 'source': 'rule', 'confidence': 0.95, 'raw_text': null},
        'nomor_referensi': {'value': '1234567', 'source': 'rule', 'confidence': 0.95, 'raw_text': null},
      },
    }));

    expect(find.text('600000'), findsOneWidget);
    expect(find.text('1234567'), findsOneWidget);
    expect(find.text('Field sudah diekstraksi.'), findsNothing);
  });

  testWidgets('field tanpa nilai ditampilkan sebagai tanda strip', (tester) async {
    await _pump(tester, _detail(extraction: {
      'fields': {'penerbit': {'value': null, 'source': 'rule', 'confidence': 0.0, 'raw_text': null}},
    }));

    expect(find.text('-'), findsWidgets);
  });

  testWidgets('tinjauan menampilkan nama peninjau, bukan UID', (tester) async {
    await _pump(tester, _detail(
      status: DocumentStatus.verified,
      extraction: {'fields': {'nominal_total': {'value': 600000, 'source': 'rule', 'confidence': 0.95, 'raw_text': null}}},
      verification: {
        'verified_by': '5khRBpCgR9NGwSNHtaYUHvknjX33',
        'verified_by_name': 'Budi Santoso (NIP 198503122010011004)',
      },
    ));

    expect(find.text('Sudah ditinjau oleh Budi Santoso (NIP 198503122010011004).'), findsOneWidget);
    expect(find.textContaining('5khRBpCgR9NGwSNHtaYUHvknjX33'), findsNothing);
  });

  testWidgets('dokumen lama tanpa nama peninjau tampil sebagai Peninjau, UID tetap disembunyikan', (tester) async {
    await _pump(tester, _detail(
      status: DocumentStatus.verified,
      extraction: {'fields': {'nominal_total': {'value': 600000, 'source': 'rule', 'confidence': 0.95, 'raw_text': null}}},
      verification: {'verified_by': '5khRBpCgR9NGwSNHtaYUHvknjX33'},
    ));

    expect(find.text('Sudah ditinjau oleh Peninjau.'), findsOneWidget);
    expect(find.textContaining('5khRBpCgR9NGwSNHtaYUHvknjX33'), findsNothing);
  });

  testWidgets('dokumen tanpa ekstraksi menampilkan keterangan status, bukan form kosong', (tester) async {
    await _pump(tester, _detail(status: DocumentStatus.processing));

    expect(find.text('Dokumen masih diproses.'), findsOneWidget);
  });
}
