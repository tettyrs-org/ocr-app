import 'package:flutter/material.dart';

import '../profile/profile_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

/// Tab Akun: data pegawai yang sedang masuk dan tombol keluar.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.profile, required this.onLogout});

  final MeProfile? profile;
  final Future<void> Function() onLogout;

  /// Dua huruf awal nama untuk avatar. Kosong atau tidak ada nama memakai '?'.
  static String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
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
                    _initials(p?.fullName),
                    style: const TextStyle(color: AppColors.indigo, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p?.fullName ?? '-', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(p?.email ?? '-', style: Theme.of(context).textTheme.bodyMedium),
                      if (p?.nip != null) ...[
                        const SizedBox(height: 2),
                        Text('NIP ${p!.nip}', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => onLogout(),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Keluar'),
            ),
          ),
        ],
      ),
    );
  }
}
