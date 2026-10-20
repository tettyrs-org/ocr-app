import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_app/features/profile/profile_api.dart';

void main() {
  group('MeProfile.fromJson', () {
    test('membaca kontrak api-spec bagian 12', () {
      final p = MeProfile.fromJson({
        'uid': 'abc',
        'email': 'budi@example.test',
        'roles': ['USER'],
        'full_name': 'Budi Santoso',
        'nip': '198503122010011004',
        'profile_completed': true,
      });
      expect(p.email, 'budi@example.test');
      expect(p.fullName, 'Budi Santoso');
      expect(p.nip, '198503122010011004');
      expect(p.profileCompleted, isTrue);
    });

    test('profil baru belum lengkap dan tanpa nama atau NIP', () {
      final p = MeProfile.fromJson({
        'email': 'baru@example.test',
        'full_name': null,
        'nip': null,
        'profile_completed': false,
      });
      expect(p.profileCompleted, isFalse);
      expect(p.fullName, isNull);
      expect(p.nip, isNull);
    });

    test('bidang yang hilang dianggap belum lengkap, bukan error', () {
      final p = MeProfile.fromJson({'email': 'x@example.test'});
      expect(p.profileCompleted, isFalse);
    });
  });
}
