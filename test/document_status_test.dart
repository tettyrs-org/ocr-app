import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_app/features/documents/document_status.dart';
import 'package:ocr_app/features/documents/document_status_chip.dart';

void main() {
  group('documentStatusFromApi', () {
    test('memetakan setiap status yang dikenal', () {
      expect(documentStatusFromApi('processing'), DocumentStatus.processing);
      expect(documentStatusFromApi('extracted'), DocumentStatus.extracted);
      expect(documentStatusFromApi('verified'), DocumentStatus.verified);
      expect(documentStatusFromApi('extraction_failed'), DocumentStatus.extractionFailed);
    });

    test('status yang tidak dikenal atau null menjadi unknown, tidak melempar error', () {
      expect(documentStatusFromApi('archived_v2'), DocumentStatus.unknown);
      expect(documentStatusFromApi(null), DocumentStatus.unknown);
    });
  });

  testWidgets('chip menampilkan label sesuai status', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: DocumentStatusChip(status: DocumentStatus.extracted)),
    ));
    expect(find.text('Perlu ditinjau'), findsOneWidget);
  });

  testWidgets('chip untuk status tak dikenal tidak crash', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: DocumentStatusChip(status: DocumentStatus.unknown)),
    ));
    expect(find.text('Status tidak dikenal'), findsOneWidget);
  });
}
