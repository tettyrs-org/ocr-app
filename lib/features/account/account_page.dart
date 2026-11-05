import 'package:flutter/material.dart';

import '../../auth/demo_mode.dart';
import '../profile/profile_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

/// Tab Akun: data pegawai yang sedang masuk dan tombol keluar.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.profile, required this.onLogout, this.roles = const []});

  final MeProfile? profile;
  final Future<void> Function() onLogout;
  final List<String> roles;

  /// Nama tampilan untuk kode peran dari BFF.
  static const _labelPeran = {'ADMIN': 'Admin', 'USER': 'Pengguna', 'VIEWER': 'Peninjau'};

  static String _peranTampil(List<String> roles) =>
      roles.map((r) => _labelPeran[r] ?? r).join(', ');

  /// Dua huruf awal nama untuk avatar. Kosong atau tidak ada nama memakai '?'.
  static String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  /// Keluar memutus sesi, jadi minta konfirmasi dulu. Tombol 'Keluar' di dialog memanggil onLogout.
  Future<void> _konfirmasiKeluar(BuildContext context) async {
    final demo = DemoMode.active;
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(demo ? 'Keluar dari mode demo?' : 'Keluar dari akun?'),
        content: Text(demo ? 'Hasil unggahan demo akan hilang.' : 'Anda perlu masuk lagi untuk melanjutkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Keluar')),
        ],
      ),
    );
    if (ya == true) await onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final demo = DemoMode.active;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Akun')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.indigoSurface,
                  child: Text(
                    demo ? 'D' : _initials(p?.fullName),
                    style: const TextStyle(color: AppColors.indigo, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(demo ? 'Mode demo' : (p?.fullName ?? '-'), style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        demo ? 'Tanpa akun. Data tidak disimpan.' : (p?.email ?? '-'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (p?.nip != null) ...[
                        const SizedBox(height: 2),
                        Text('NIP ${p!.nip}', style: Theme.of(context).textTheme.bodySmall),
                      ],
                      if (!demo && roles.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Peran: ${_peranTampil(roles)}', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Pengaturan dalam bentuk daftar, seperti aplikasi modern: aksi keluar ada di baris terakhir.
          AppCard(
            padding: EdgeInsets.zero,
            child: InkWell(
              onTap: () => _konfirmasiKeluar(context),
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded, size: 20, color: AppColors.error),
                    const SizedBox(width: AppSpace.md),
                    Text(
                      demo ? 'Keluar dari demo' : 'Keluar',
                      style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
