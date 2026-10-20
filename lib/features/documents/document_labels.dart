// Label ramah untuk tampilan dokumen. Kode jenis dari API tidak pernah ditampilkan mentah ke pengguna.

const _bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

/// Nama ramah untuk jenis dokumen dari API (api-spec bagian 2, doc_type).
String docTypeLabel(String? docType) {
  return switch (docType) {
    'IDENTITY_CARD' => 'Kartu identitas (KTP)',
    'SURAT_TUGAS' => 'Surat tugas',
    'SPD' => 'Surat perjalanan dinas',
    'REIMBURSEMENT_FUEL' => 'Bukti BBM',
    'PARKING_CARD' => 'Kartu parkir',
    'RECEIPT' => 'Struk',
    'OTHER' => 'Dokumen lainnya',
    _ => 'Belum dikenali',
  };
}

/// Waktu dalam WIB (Asia/Jakarta, UTC+7), apa pun zona perangkat pengguna.
DateTime keJakarta(DateTime waktu) => waktu.toUtc().add(const Duration(hours: 7));

/// Tanggal dan jam unggah dalam format Indonesia, mis. "19 Okt 2026, 16.05" (WIB).
String formatTanggalUnggah(DateTime? waktu) {
  if (waktu == null) return '';
  final l = keJakarta(waktu);
  final jam = l.hour.toString().padLeft(2, '0');
  final menit = l.minute.toString().padLeft(2, '0');
  return '${l.day} ${_bulan[l.month - 1]} ${l.year}, $jam.$menit';
}
