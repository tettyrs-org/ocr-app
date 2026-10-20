import 'package:flutter/material.dart';

/// Token warna sesuai documents/product/app-structure.md bagian 5 dan skill ux-design.
/// Semua warna UI diambil dari sini; jangan tulis warna hex langsung di halaman.
abstract final class AppColors {
  static const background = Color(0xFFF8FAFC); // slate-50, jangan pakai putih murni
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF1F5F9); // slate-100, ikon dan area sekunder
  static const border = Color(0xFFE2E8F0); // slate-200
  static const borderStrong = Color(0xFFCBD5E1); // slate-300
  static const primary = Color(0xFF0F172A); // slate-900
  static const accent = Color(0xFF7C3AED); // violet-600, momen AI saja
  static const error = Color(0xFFE11D48); // rose-600
  static const errorSurface = Color(0xFFFFF1F2); // rose-50
  static const text = Color(0xFF475569); // slate-600
  static const heading = Color(0xFF0F172A);
  static const teal = Color(0xFF0F766E); // teal-700, status tersimpan
  static const tealSurface = Color(0xFFCCFBF1); // teal-100
  static const warning = Color(0xFFB45309); // amber-700
  static const warningSurface = Color(0xFFFEF3C7); // amber-100
  static const indigo = Color(0xFF4F46E5); // indigo-600, fokus dan status perlu ditinjau
  static const indigoSurface = Color(0xFFEEF2FF); // indigo-50
  static const slate = Color(0xFF64748B); // slate-500
}

/// Radius konsisten: kartu dan tombol 12, chip penuh.
abstract final class AppRadius {
  static const card = 12.0;
  static const button = 12.0;
  static const pill = 999.0;
}

/// Bayangan tipis untuk kartu (spesifikasi app-structure.md bagian 5). Dipakai bersama border.
abstract final class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 6, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 2, offset: Offset(0, 1)),
  ];
}

/// Nama family font. Didaftarkan di pubspec.yaml (bagian `fonts`).
abstract final class AppFonts {
  static const body = 'Inter';
  static const display = 'InterTight';
}

/// Jarak konsisten. Gunakan kelipatan 4.
abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    onPrimary: AppColors.surface,
    secondary: AppColors.accent,
    error: AppColors.error,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    outline: AppColors.borderStrong,
    outlineVariant: AppColors.border,
  );

  // Teks memakai Inter; judul memakai Inter Tight (app-structure.md bagian 5).
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: AppFonts.body);
  final textTheme = base.textTheme.copyWith(
    headlineSmall: base.textTheme.headlineSmall?.copyWith(
      color: AppColors.heading,
      fontFamily: AppFonts.display,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      color: AppColors.heading,
      fontFamily: AppFonts.display,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      color: AppColors.heading,
      fontFamily: AppFonts.display,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(color: AppColors.text, height: 1.5),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(color: AppColors.text, height: 1.5),
    bodySmall: base.textTheme.bodySmall?.copyWith(color: AppColors.slate, height: 1.4),
    labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );

  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button));
  const buttonText = TextStyle(fontWeight: FontWeight.w600, fontSize: 15);

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: AppColors.background,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.heading,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: AppColors.indigoSurface,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? AppColors.heading : AppColors.slate,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? AppColors.indigo : AppColors.slate,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x0F0F172A),
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.primary,
      contentTextStyle: const TextStyle(color: AppColors.surface, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      extendedTextStyle: buttonText,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.surface,
        disabledBackgroundColor: AppColors.borderStrong,
        disabledForegroundColor: AppColors.surface,
        minimumSize: const Size(48, 48),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.heading,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: AppColors.borderStrong),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.heading,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      labelStyle: const TextStyle(color: AppColors.text),
      floatingLabelStyle: const TextStyle(color: AppColors.heading, fontWeight: FontWeight.w600),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: const BorderSide(color: AppColors.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: const BorderSide(color: AppColors.borderStrong),
      ),
      // Focus ring terlihat (skill ux-design: jangan hilangkan outline tanpa pengganti).
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: const BorderSide(color: AppColors.indigo, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
  );
}
