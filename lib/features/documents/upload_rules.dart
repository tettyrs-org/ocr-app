import 'dart:typed_data';

/// Aturan unggah sisi klien. Hanya umpan balik cepat: server tetap memvalidasi ulang (api-spec bagian 2).
enum UploadKind { jpeg, png, pdf }

class UploadRules {
  UploadRules._();

  static const maxImageBytes = 10 * 1024 * 1024;
  static const maxPdfBytes = 25 * 1024 * 1024;
  static const maxPdfPages = 15;

  static const acceptedFormatsLabel = 'JPG, PNG, atau PDF';

  /// Menentukan jenis berkas dari magic bytes, bukan dari ekstensi.
  static UploadKind? detect(Uint8List bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return UploadKind.jpeg;
    }
    if (bytes.length >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      return UploadKind.png;
    }
    if (bytes.length >= 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) {
      return UploadKind.pdf;
    }
    return null;
  }

  /// Perkiraan jumlah halaman PDF dari penanda `/Type /Page` (bukan `/Pages`).
  /// Hanya perkiraan; server yang menentukan batas halaman yang sebenarnya.
  static int estimatePdfPages(Uint8List bytes) {
    final text = String.fromCharCodes(bytes);
    final matches = RegExp(r'/Type\s*/Page(?!s)').allMatches(text);
    return matches.length;
  }

  /// Mengembalikan pesan kesalahan dalam bahasa Indonesia, atau null bila berkas lolos.
  static String? validate(Uint8List bytes) {
    if (bytes.isEmpty) return 'Berkas kosong. Pilih berkas lain.';
    final kind = detect(bytes);
    if (kind == null) {
      return 'Format berkas tidak didukung. Gunakan $acceptedFormatsLabel.';
    }
    if (kind == UploadKind.pdf) {
      if (bytes.length > maxPdfBytes) return 'Ukuran PDF melebihi 25 MB.';
      final pages = estimatePdfPages(bytes);
      if (pages > maxPdfPages) {
        return 'PDF memiliki lebih dari $maxPdfPages halaman. Pisahkan berkas lalu unggah satu per satu.';
      }
    } else if (bytes.length > maxImageBytes) {
      return 'Ukuran gambar melebihi 10 MB.';
    }
    return null;
  }
}
