import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_app/features/documents/upload_rules.dart';

Uint8List _bytes(List<int> head, {int totalLength = 16}) {
  final out = Uint8List(totalLength);
  out.setAll(0, head);
  return out;
}

Uint8List _pdfWithPages(int pages) {
  final buf = StringBuffer('%PDF-1.7\n');
  for (var i = 0; i < pages; i++) {
    buf.write('<< /Type /Page /Parent 1 0 R >>\n');
  }
  buf.write('<< /Type /Pages /Count $pages >>\n');
  return Uint8List.fromList(utf8.encode(buf.toString()));
}

void main() {
  group('deteksi format dari magic bytes', () {
    test('JPEG dikenali dari FF D8 FF', () {
      expect(UploadRules.detect(_bytes([0xFF, 0xD8, 0xFF, 0xE0])), UploadKind.jpeg);
    });

    test('PNG dikenali dari 89 50 4E 47', () {
      expect(UploadRules.detect(_bytes([0x89, 0x50, 0x4E, 0x47])), UploadKind.png);
    });

    test('PDF dikenali dari %PDF', () {
      expect(UploadRules.detect(_bytes([0x25, 0x50, 0x44, 0x46])), UploadKind.pdf);
    });

    test('ekstensi tidak dipakai: teks biasa ditolak', () {
      expect(UploadRules.detect(Uint8List.fromList(utf8.encode('bukan gambar'))), isNull);
    });
  });

  group('validate', () {
    test('berkas kosong ditolak', () {
      expect(UploadRules.validate(Uint8List(0)), 'Berkas kosong. Pilih berkas lain.');
    });

    test('format tidak didukung ditolak dengan pesan yang menyebut format yang diterima', () {
      final msg = UploadRules.validate(Uint8List.fromList(utf8.encode('GIF89a')));
      expect(msg, contains('JPG, PNG, atau PDF'));
    });

    test('gambar tepat 10 MB lolos, lebih dari itu ditolak', () {
      final ok = _bytes([0xFF, 0xD8, 0xFF], totalLength: UploadRules.maxImageBytes);
      final tooBig = _bytes([0xFF, 0xD8, 0xFF], totalLength: UploadRules.maxImageBytes + 1);
      expect(UploadRules.validate(ok), isNull);
      expect(UploadRules.validate(tooBig), 'Ukuran gambar melebihi 10 MB.');
    });

    test('PDF dengan 15 halaman lolos, 16 halaman ditolak', () {
      expect(UploadRules.validate(_pdfWithPages(15)), isNull);
      expect(UploadRules.validate(_pdfWithPages(16)), contains('lebih dari 15 halaman'));
    });

    test('PDF lebih dari 25 MB ditolak', () {
      final tooBig = _bytes([0x25, 0x50, 0x44, 0x46], totalLength: UploadRules.maxPdfBytes + 1);
      expect(UploadRules.validate(tooBig), 'Ukuran PDF melebihi 25 MB.');
    });
  });

  group('estimatePdfPages', () {
    test('menghitung /Type /Page dan mengabaikan /Pages', () {
      expect(UploadRules.estimatePdfPages(_pdfWithPages(3)), 3);
    });
  });
}
