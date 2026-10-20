import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../theme/app_theme.dart';

// Kosong berarti satu origin dengan aplikasi (Firebase Hosting melayani /bff/* lewat Cloud Function).
const _bffBaseUrl = String.fromEnvironment('BFF_BASE_URL', defaultValue: '');

/// Form undangan pegawai (auth-firebase.md bagian 8, api-spec.md bagian 16).
///
/// Token ada di fragment URL (`/undangan#<token>`), sehingga tidak ikut terkirim ke server dan tidak masuk log.
/// Form hanya bisa dikirim sekali: setelah berhasil, tautan ini tidak bisa dipakai lagi.
/// Sandi dikirim ke BFF, yang memasangkannya ke Firebase. Aplikasi dan database tidak menyimpannya.
class InvitationPage extends StatefulWidget {
  const InvitationPage({super.key, this.baseUrl = _bffBaseUrl});

  final String baseUrl;

  @override
  State<InvitationPage> createState() => _InvitationPageState();
}

class _InvitationPageState extends State<InvitationPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nip = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  String? _token;
  String? _email;
  bool _checking = true;
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final fragment = Uri.base.fragment;
    _token = fragment.isEmpty ? null : Uri.decodeComponent(fragment);
    _check();
  }

  @override
  void dispose() {
    _name.dispose();
    _nip.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _checking = false;
        _error = invalidMessage;
      });
      return;
    }
    try {
      final res = await http.post(
        Uri.parse('${widget.baseUrl}/bff/undangan/cek'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      );
      final body = _decode(res);
      if (res.statusCode == 200) {
        setState(() => _email = body['data']?['email'] as String?);
      } else {
        setState(() => _error = _messageOf(body, res.statusCode));
      }
    } catch (_) {
      setState(() => _error = 'Tidak ada koneksi. Periksa jaringan lalu coba lagi.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await http.post(
        Uri.parse('${widget.baseUrl}/bff/undangan/selesai'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': _token,
          'full_name': _name.text.trim(),
          'nip': _nip.text.trim(),
          'password': _password.text,
        }),
      );
      final body = _decode(res);
      if (res.statusCode == 200) {
        setState(() => _done = true);
      } else {
        setState(() => _error = _messageOf(body, res.statusCode));
      }
    } catch (_) {
      setState(() => _error = 'Tidak ada koneksi. Periksa jaringan lalu coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const invalidMessage = 'Tautan undangan tidak valid atau sudah tidak berlaku. Minta admin mengirim undangan baru.';

  Map<String, dynamic> _decode(http.Response res) {
    try {
      return res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String _messageOf(Map<String, dynamic> body, int status) {
    final err = body['error'] as Map<String, dynamic>?;
    final code = err?['code'] as String?;
    if (code == 'INVITATION_INVALID') return invalidMessage;
    if (code == 'VALIDATION_ERROR' || code == 'CONFLICT' || code == 'WEAK_PASSWORD') {
      return err?['message'] as String? ?? 'Ada isian yang belum sesuai.';
    }
    return status >= 500 ? 'Server sedang bermasalah. Coba lagi beberapa saat.' : 'Permintaan gagal. Coba lagi.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Aktivasi akun')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: _checking
                  ? const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _done
                      ? _doneView(context)
                      : _email == null
                          ? _invalidView(context)
                          : _formView(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _invalidView(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_error ?? invalidMessage, textAlign: TextAlign.center),
      ],
    );
  }

  Widget _doneView(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Profil dan sandi Anda sudah tersimpan. Formulir ini hanya bisa dipakai sekali.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.heading, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Masuk'),
          ),
        ),
      ],
    );
  }

  Widget _formView(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Lengkapi data Anda. Email tidak dapat diubah. Formulir hanya bisa dikirim sekali.',
            style: const TextStyle(color: AppColors.text, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _email,
            enabled: false,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nama lengkap'),
            validator: (v) => (v?.trim().length ?? 0) < 3 ? 'Nama lengkap wajib diisi (minimal 3 karakter)' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nip,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'NIP (18 digit)'),
            validator: (v) => RegExp(r'^\d{18}$').hasMatch(v?.trim() ?? '') ? null : 'NIP harus 18 digit angka',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(labelText: 'Sandi baru'),
            validator: (v) => _passwordError(v ?? ''),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Ulangi sandi baru'),
            validator: (v) => v != _password.text ? 'Sandi tidak sama' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Menyimpan...' : 'Simpan'),
            ),
          ),
        ],
      ),
    );
  }

  /// Kebijakan sandi: minimal 8 karakter dengan huruf dan angka. Sandi tidak pernah dicatat aplikasi.
  static String? _passwordError(String v) {
    if (v.length < 8) return 'Sandi minimal 8 karakter';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) return 'Sandi harus memuat huruf dan angka';
    return null;
  }
}
