import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_app/features/documents/review_model.dart';

Map<String, dynamic> _sample() => {
      'nomor_surat': {'value': '090/ST/IX/2026', 'confidence': 0.8, 'source': 'rule', 'raw_text': '090/ST/LX/2026'},
      'pemberi_tugas': {
        'nama': {'value': 'Dr. Ahmad Hidayat, M.M.', 'confidence': 0.95, 'source': 'rule'},
      },
      'pegawai': [
        {
          'nama': {'value': 'Budi Santoso', 'confidence': 0.95, 'source': 'rule'},
          'nip': {'value': '198503122010011004', 'confidence': 0.95, 'source': 'rule'},
          'tingkat_biaya_perjalanan': {'value': null, 'confidence': 0.0, 'source': 'rule'},
        },
        {
          'nama': {'value': 'Siti Rahayu', 'confidence': 0.4, 'source': 'rule'},
          'nip': {'value': '199007152015022003', 'confidence': 0.95, 'source': 'rule'},
        },
      ],
      'pengikut': <dynamic>[],
      'nominal': {'value': 1500000, 'confidence': 0.95, 'source': 'rule'},
    };

void main() {
  group('flattenReviewFields', () {
    test('label KTP mengikuti kunci yang dikirim ms-ocr, bukan nama kunci mentah', () {
      final rows = flattenReviewFields({
        'nik': {'value': '3271014567890123', 'confidence': 0.5, 'source': 'rule', 'correction': 'derived'},
        'rt_rw': {'value': '007/008', 'confidence': 0.8, 'source': 'rule'},
        'kelurahan_desa': {'value': 'PEGADUNGAN', 'confidence': 0.8, 'source': 'rule'},
        'berlaku_hingga': {'value': '22-02-2017', 'confidence': 0.8, 'source': 'rule'},
      });
      final labels = {for (final r in rows) r.path: r.label};
      expect(labels['nik'], 'NIK');
      expect(labels['rt_rw'], 'RT/RW');
      expect(labels['kelurahan_desa'], 'Kelurahan/Desa');
      expect(labels['berlaku_hingga'], 'Berlaku hingga');
    });

    test('memberi path dan label untuk daun, termasuk elemen array', () {
      final rows = flattenReviewFields(_sample());
      final paths = rows.map((r) => r.path).toList();
      expect(paths, contains('nomor_surat'));
      expect(paths, contains('pemberi_tugas.nama'));
      expect(paths, contains('pegawai[0].nip'));
      expect(paths, contains('pegawai[1].nama'));

      final nip = rows.firstWhere((r) => r.path == 'pegawai[0].nip');
      expect(nip.label, 'NIP');
      expect(nip.group, 'Pegawai 1');
      expect(rows.firstWhere((r) => r.path == 'pegawai[1].nama').group, 'Pegawai 2');
    });

    test('menandai field keyakinan rendah dan nilai kosong', () {
      final rows = flattenReviewFields(_sample());
      expect(rows.firstWhere((r) => r.path == 'pegawai[1].nama').needsReview, isTrue);
      expect(rows.firstWhere((r) => r.path == 'nomor_surat').needsReview, isFalse);
      expect(rows.firstWhere((r) => r.path == 'pegawai[0].tingkat_biaya_perjalanan').isEmpty, isTrue);
      // Field kosong (confidence 0) ikut dicek karena pengguna harus mengisinya: nama Siti dan tingkat biaya.
      expect(countNeedingReview(rows), 2);
    });

    test('pengikut kosong tidak menghasilkan baris', () {
      final rows = flattenReviewFields(_sample());
      expect(rows.where((r) => r.path.startsWith('pengikut')), isEmpty);
    });
  });

  group('buildVerificationFields', () {
    test('field yang tidak diubah mempertahankan source asli', () {
      final original = _sample();
      final edited = {for (final r in flattenReviewFields(original)) r.path: reviewInitialText(r.value)};
      final out = buildVerificationFields(original, edited);
      final nomor = out['nomor_surat'] as Map<String, dynamic>;
      expect(nomor, {'value': '090/ST/IX/2026', 'source': 'rule'});
    });

    test('field yang diubah menjadi manual dan nilai angka tetap angka', () {
      final original = _sample();
      final edited = {
        for (final r in flattenReviewFields(original)) r.path: reviewInitialText(r.value),
        'nomor_surat': '090/ST/IX/2027',
        'nominal': '2000000',
      };
      final out = buildVerificationFields(original, edited);
      expect(out['nomor_surat'], {'value': '090/ST/IX/2027', 'source': 'manual'});
      expect(out['nominal'], {'value': 2000000, 'source': 'manual'});
    });

    test('array tetap array dengan urutan sama', () {
      final original = _sample();
      final edited = {
        for (final r in flattenReviewFields(original)) r.path: reviewInitialText(r.value),
        'pegawai[1].nama': 'Siti R.',
      };
      final out = buildVerificationFields(original, edited);
      final pegawai = out['pegawai'] as List;
      expect(pegawai.length, 2);
      expect((pegawai[1] as Map)['nama'], {'value': 'Siti R.', 'source': 'manual'});
      expect((pegawai[0] as Map)['nip'], {'value': '198503122010011004', 'source': 'rule'});
    });

    test('kosongkan teks berarti value null bila sebelumnya ada nilai', () {
      final original = _sample();
      final edited = {
        for (final r in flattenReviewFields(original)) r.path: reviewInitialText(r.value),
        'nomor_surat': '   ',
      };
      final out = buildVerificationFields(original, edited);
      expect(out['nomor_surat'], {'value': null, 'source': 'manual'});
    });
  });
}
