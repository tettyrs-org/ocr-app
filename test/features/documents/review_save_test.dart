import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ocr_app/auth/bff_service.dart';
import 'package:ocr_app/features/documents/document_review_page.dart';
import 'package:ocr_app/features/documents/document_status.dart';
import 'package:ocr_app/features/documents/documents_api.dart';

/// Tiruan BFF yang tidak dipakai: semua pemanggilan lewat method yang di-override di bawah.
class _NoBff implements BffService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeApi extends DocumentsApi {
  _FakeApi() : super(_NoBff());

  int verifyCalls = 0;

  @override
  Future<DocumentDetail> detail(String documentId) async => DocumentDetail(
        summary: DocumentSummary(
          documentId: documentId,
          docRef: 'DOC-12345678',
          docType: 'RECEIPT',
          status: DocumentStatus.extracted,
          createdAt: DateTime(2026, 10, 19),
          fieldsNeedReview: 1,
        ),
        mimeType: 'image/jpeg',
        sizeBytes: 1000,
        fileAvailable: true,
        extraction: {
          'schema_version': '1.0',
          'doc_type': 'RECEIPT',
          'fields': {
            'nominal_total': {'value': 600000, 'source': 'rule', 'confidence': 0.95, 'raw_text': null},
          },
        },
        verification: null,
      );

  @override
  Future<void> verify({required String documentId, required String docType, required Map<String, dynamic> fields}) async {
    verifyCalls++;
  }
}

void main() {
  testWidgets('setelah simpan (tinjau dibuka dengan go, tanpa halaman sebelumnya), tidak blank dan menuju daftar', (tester) async {
    final api = _FakeApi();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: TextButton(
                  onPressed: () => ctx.go('/dokumen/doc-1/tinjau'),
                  child: const Text('Buka tinjau'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/dokumen',
          builder: (context, state) => const Scaffold(body: Center(child: Text('Daftar dokumen'))),
        ),
        GoRoute(
          path: '/dokumen/:id/tinjau',
          builder: (context, state) => DocumentReviewPage(api: api, documentId: state.pathParameters['id']!),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Buka tinjau'));
    await tester.pumpAndSettle();

    expect(find.text('Simpan'), findsOneWidget);
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(api.verifyCalls, 1);
    expect(find.text('Simpan'), findsNothing, reason: 'halaman tinjau harus tertutup');
    expect(find.text('Daftar dokumen'), findsOneWidget, reason: 'halaman daftar harus tampil, bukan layar kosong');
    expect(tester.takeException(), isNull);
  });
}
