import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_app/features/documents/review_model.dart';

void main() {
  group('format nominal', () {
    test('angka ribuan diberi titik', () {
      expect(formatNominal(20000), '20.000');
      expect(formatNominal(1530000), '1.530.000');
      expect(formatNominal(950), '950');
    });

    test('nominal tampil dengan titik, nilai server tetap angka', () {
      expect(reviewInitialText(20000, path: 'nominal_total'), '20.000');
      expect(reviewInitialText(20000), '20000');
    });

    test('field lain tidak diberi titik', () {
      expect(reviewInitialText(2.5, path: 'liter'), '2.5');
      expect(reviewInitialText(1994, path: 'tahun'), '1994');
    });

    test('nilai yang tidak diubah tetap angka asli', () {
      final original = {
        'nominal_total': {'value': 20000, 'source': 'rule'},
      };
      final edited = {'nominal_total': '20.000'};

      final out = buildVerificationFields(original, edited);

      expect(out['nominal_total']['value'], 20000);
      expect(out['nominal_total']['source'], 'rule');
    });

    test('nominal yang diubah dengan titik diuraikan sebagai angka utuh', () {
      final original = {
        'nominal_total': {'value': 20000, 'source': 'rule'},
      };
      final edited = {'nominal_total': '192.000'};

      final out = buildVerificationFields(original, edited);

      expect(out['nominal_total']['value'], 192000);
      expect(out['nominal_total']['source'], 'manual');
    });
  });
}
