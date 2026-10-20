import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_app/features/documents/document_labels.dart';

void main() {
  test('kode jenis dokumen diganti label bahasa Indonesia', () {
    expect(docTypeLabel('IDENTITY_CARD'), 'Kartu identitas (KTP)');
    expect(docTypeLabel('REIMBURSEMENT_FUEL'), 'Bukti BBM');
    expect(docTypeLabel(null), 'Belum dikenali');
  });

  test('tanggal unggah ditampilkan dengan nama bulan Indonesia', () {
    // 09.05 UTC sama dengan 16.05 WIB, apa pun zona perangkat.
    expect(formatTanggalUnggah(DateTime.utc(2026, 10, 19, 9, 5)), '19 Okt 2026, 16.05');
    expect(formatTanggalUnggah(null), '');
  });

  test('waktu dengan offset +07:00 dari API tetap tampil sebagai WIB', () {
    expect(formatTanggalUnggah(DateTime.parse('2026-10-20T14:08:33.864873+07:00')), '20 Okt 2026, 14.08');
  });
}
