// Model tinjau dan koreksi (S9). Murni tanpa widget agar bisa diuji.
//
// Bentuk field dari API (extraction-schema.md bagian 1): daun berisi `value`, `confidence`, `source`,
// `raw_text`, `correction`, `page`, `bbox`. Kelompok berupa objek, dan `pegawai`/`pengikut` berupa array.
// Path daun dibentuk seperti `pegawai[0].nip` agar bisa dipetakan kembali saat menyimpan.

const reviewConfidenceThreshold = 0.8;

const _labels = <String, String>{
  'nomor_surat': 'Nomor surat',
  'tanggal_surat': 'Tanggal surat',
  'dasar_penugasan': 'Dasar penugasan',
  'pemberi_tugas': 'Pemberi tugas',
  'pegawai': 'Pegawai',
  'nama': 'Nama',
  'nip': 'NIP',
  'pangkat_golongan': 'Pangkat/golongan',
  'jabatan': 'Jabatan',
  'uraian_tugas': 'Uraian tugas',
  'tempat_tujuan': 'Tempat tujuan',
  'tanggal_mulai': 'Tanggal mulai',
  'tanggal_selesai': 'Tanggal selesai',
  'sumber_biaya': 'Sumber biaya',
  'nomor_spd': 'Nomor SPD',
  'tanggal_spd': 'Tanggal SPD',
  'pejabat_pembuat_komitmen': 'Pejabat pembuat komitmen',
  'tingkat_biaya_perjalanan': 'Tingkat biaya',
  'maksud_perjalanan': 'Maksud perjalanan',
  'alat_angkut': 'Alat angkut',
  'tempat_kedudukan': 'Tempat kedudukan',
  'tanggal_berangkat': 'Tanggal berangkat',
  'tanggal_harus_kembali': 'Tanggal kembali',
  'lama_perjalanan_hari': 'Lama perjalanan (hari)',
  'pengikut': 'Pengikut',
  'hubungan': 'Hubungan',
  'pembebanan_anggaran': 'Pembebanan anggaran',
  'instansi': 'Instansi',
  'akun': 'Akun',
  'keterangan': 'Keterangan',
  'tanggal': 'Tanggal',
  'penerbit': 'Penerbit',
  'nomor_referensi': 'Nomor referensi',
  'nominal_total': 'Nominal total (Rp)',
  'kategori': 'Kategori',
  // KTP (extraction-schema.md bagian KTP). Kunci harus sama dengan yang dikirim ms-ocr.
  'nik': 'NIK',
  'tempat_lahir': 'Tempat lahir',
  'tanggal_lahir': 'Tanggal lahir',
  'jenis_kelamin': 'Jenis kelamin',
  'alamat': 'Alamat',
  'rt_rw': 'RT/RW',
  'kelurahan_desa': 'Kelurahan/Desa',
  'kecamatan': 'Kecamatan',
  'agama': 'Agama',
  'status_perkawinan': 'Status perkawinan',
  'pekerjaan': 'Pekerjaan',
  'kewarganegaraan': 'Kewarganegaraan',
  'berlaku_hingga': 'Berlaku hingga',
};

const _sources = {'rule', 'llm', 'manual'};

/// Satu baris yang bisa diedit di layar tinjau.
class ReviewField {
  ReviewField({
    required this.path,
    required this.group,
    required this.label,
    required this.value,
    required this.source,
    required this.confidence,
    required this.rawText,
    required this.correction,
  });

  final String path;
  final String group;
  final String label;

  /// Nilai asli dari ekstraksi (String, num, atau null).
  final Object? value;
  final String source;
  final double? confidence;
  final String? rawText;
  final String? correction;

  bool get needsReview => confidence != null && confidence! < reviewConfidenceThreshold;
  bool get isEmpty => value == null;
}

/// Meratakan `fields` menjadi daftar baris untuk layar tinjau, dalam urutan dokumen.
List<ReviewField> flattenReviewFields(Map<String, dynamic> fields) {
  final out = <ReviewField>[];
  _walk(fields, '', '', out);
  return out;
}

void _walk(Object? node, String path, String group, List<ReviewField> out) {
  if (node is Map && node.containsKey('source')) {
    out.add(_leafFrom(node, path, group));
    return;
  }
  if (node is Map) {
    node.forEach((key, child) {
      final k = key.toString();
      final childPath = path.isEmpty ? k : '$path.$k';
      // Grup tingkat atas: nama kelompok (mis. "Pemberi tugas"). Elemen array mengganti grupnya sendiri.
      // Field tingkat atas (daun) tidak punya grup, supaya labelnya tidak tampil dobel sebagai judul grup.
      final childGroup = group.isEmpty ? (child is Map && child.containsKey('source') ? '' : _labelOf(k)) : group;
      _walk(child, childPath, childGroup, out);
    });
    return;
  }
  if (node is List) {
    for (var i = 0; i < node.length; i++) {
      final elPath = '$path[$i]';
      final elGroup = '${_labelOf(_lastSegment(path))} ${i + 1}';
      _walk(node[i], elPath, elGroup, out);
    }
  }
}

ReviewField _leafFrom(Map node, String path, String group) {
  final rawSource = node['source']?.toString();
  final conf = node['confidence'];
  return ReviewField(
    path: path,
    group: group,
    label: _labelOf(_lastSegment(path)),
    value: node['value'],
    source: _sources.contains(rawSource) ? rawSource! : 'rule',
    confidence: conf is num ? conf.toDouble() : null,
    rawText: node['raw_text']?.toString(),
    correction: node['correction']?.toString(),
  );
}

String _lastSegment(String path) {
  final dot = path.lastIndexOf('.');
  final seg = dot < 0 ? path : path.substring(dot + 1);
  return seg.replaceAll(RegExp(r'\[\d+\]$'), '');
}

String _labelOf(String key) {
  final known = _labels[key];
  if (known != null) return known;
  final spaced = key.replaceAll('_', ' ').trim();
  return spaced.isEmpty ? key : spaced[0].toUpperCase() + spaced.substring(1);
}

/// Menyusun ulang `fields` untuk PUT /verification (api-spec bagian 5). Klien mengirim seluruh kumpulan.
///
/// `edited` memuat nilai teks baru per path. Daun yang nilainya berubah diberi `source: manual`;
/// daun yang tidak berubah mempertahankan `source` asli. Nilai numerik tetap numerik bila bisa diurai.
Map<String, dynamic> buildVerificationFields(
  Map<String, dynamic> original,
  Map<String, String> edited,
) {
  Object? rebuild(Object? node, String path) {
    if (node is Map && node.containsKey('source')) {
      final orig = node['value'];
      final rawSource = node['source']?.toString();
      final text = edited[path];
      final changed = text != null && text != _asText(orig);
      final value = changed ? _parseEdited(text, orig) : orig;
      final source = changed ? 'manual' : (_sources.contains(rawSource) ? rawSource! : 'rule');
      return {'value': value, 'source': source};
    }
    if (node is Map) {
      final out = <String, dynamic>{};
      node.forEach((key, child) {
        final k = key.toString();
        out[k] = rebuild(child, path.isEmpty ? k : '$path.$k');
      });
      return out;
    }
    if (node is List) {
      return [for (var i = 0; i < node.length; i++) rebuild(node[i], '$path[$i]')];
    }
    return node;
  }

  return Map<String, dynamic>.from(rebuild(original, '') as Map);
}

String? _asText(Object? v) => v?.toString();

Object? _parseEdited(String text, Object? original) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  if (original is num) {
    final asInt = int.tryParse(trimmed);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(trimmed);
    if (asDouble != null) return asDouble;
  }
  return trimmed;
}

/// Teks awal untuk kolom edit. Null tampil sebagai kosong.
String reviewInitialText(Object? value) => value?.toString() ?? '';

/// Konteks ringkas untuk pengguna: jenis dokumen dan jumlah baris yang perlu diperiksa.
int countNeedingReview(List<ReviewField> rows) => rows.where((r) => r.needsReview).length;

