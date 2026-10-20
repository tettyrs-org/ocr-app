import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Kartu putih dengan batas tipis. Judul opsional di atas isi.
class AppCard extends StatelessWidget {
  const AppCard({super.key, this.title, this.padding = const EdgeInsets.all(AppSpace.lg), required this.child});

  final String? title;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpace.md),
          ],
          child,
        ],
      ),
    );
  }
}

/// Tampilan kosong, error, atau sedang memuat: ikon, judul, penjelasan, dan satu aksi opsional.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor = AppColors.slate,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Icon(icon, size: 30, color: iconColor),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            if (message != null) ...[
              const SizedBox(height: AppSpace.sm),
              Text(message!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpace.lg),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pesan status di dalam halaman. Nada menentukan warna dan ikon.
enum AppBannerTone { error, warning, info }

class AppBanner extends StatelessWidget {
  const AppBanner({super.key, required this.message, this.details = const [], this.tone = AppBannerTone.error});

  final String message;
  final List<String> details;
  final AppBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final (fg, bg, icon) = switch (tone) {
      AppBannerTone.error => (AppColors.error, AppColors.errorSurface, Icons.error_outline_rounded),
      AppBannerTone.warning => (AppColors.warning, AppColors.warningSurface, Icons.warning_amber_rounded),
      AppBannerTone.info => (AppColors.indigo, AppColors.indigoSurface, Icons.info_outline_rounded),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(color: fg.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
                  for (final d in details)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.xs),
                      child: Text(d, style: TextStyle(color: fg, fontSize: 13)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Baris label dan nilai, dipakai untuk data hasil ekstraksi.
class AppKeyValue extends StatelessWidget {
  const AppKeyValue({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.heading, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
