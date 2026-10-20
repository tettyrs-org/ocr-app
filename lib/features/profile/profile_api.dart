import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/bff_service.dart';

/// Profil pengguna yang sedang login (api-spec.md bagian 12).
class MeProfile {
  MeProfile({
    required this.email,
    required this.fullName,
    required this.nip,
    required this.profileCompleted,
  });

  final String email;
  final String? fullName;
  final String? nip;
  final bool profileCompleted;

  factory MeProfile.fromJson(Map<String, dynamic> j) => MeProfile(
        email: j['email'] as String? ?? '',
        fullName: j['full_name'] as String?,
        nip: j['nip'] as String?,
        profileCompleted: j['profile_completed'] as bool? ?? false,
      );
}

/// Kesalahan dari endpoint profil. Pesan sudah dalam bahasa pengguna.
class ProfileException implements Exception {
  ProfileException(this.message, {this.details = const []});
  final String message;
  final List<String> details;

  @override
  String toString() => message;
}

class ProfileApi {
  ProfileApi(this._bff);

  final BffService _bff;

  Future<MeProfile> me() async {
    final res = await _bff.apiGet('/v1/me');
    return MeProfile.fromJson(_data(res));
  }

  Future<MeProfile> complete({required String fullName, required String nip}) async {
    final res = await _bff.apiWrite(
      'PUT',
      '/v1/me/profile',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'full_name': fullName, 'nip': nip}),
    );
    return MeProfile.fromJson(_data(res));
  }

  Map<String, dynamic> _data(http.Response res) {
    final body = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      final err = body['error'] as Map<String, dynamic>?;
      final code = err?['code'] as String?;
      // Pesan validasi dari server spesifik per field (NIP tidak ada, nama tidak cocok), jadi dipakai langsung.
      final message = code == 'VALIDATION_ERROR' && err?['message'] is String
          ? err!['message'] as String
          : _messageFor(code, res.statusCode);
      throw ProfileException(message);
    }
    return body['data'] as Map<String, dynamic>;
  }

  static String _messageFor(String? code, int status) {
    return switch (code) {
      'PROFILE_ALREADY_COMPLETE' => 'Profil Anda sudah lengkap.',
      'CONFLICT' => 'NIP ini sudah dipakai akun lain. Hubungi admin.',
      'VALIDATION_ERROR' => 'Ada isian yang belum sesuai. Periksa nama dan NIP Anda.',
      'UNAUTHENTICATED' => 'Sesi habis. Masuk lagi untuk melanjutkan.',
      _ => status >= 500 ? 'Server sedang bermasalah. Coba lagi beberapa saat.' : 'Permintaan gagal. Coba lagi.',
    };
  }
}
