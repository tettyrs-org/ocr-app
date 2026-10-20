import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/app_session.dart';
import '../features/account/account_page.dart';
import '../features/auth/login_page.dart';
import '../features/documents/document_detail_page.dart';
import '../features/documents/document_review_page.dart';
import '../features/documents/documents_api.dart';
import '../features/documents/documents_page.dart';
import '../features/documents/processing_page.dart';
import '../features/invitation/invitation_page.dart';
import '../features/profile/profile_api.dart';
import '../features/profile/profile_gate.dart';
import '../features/reset/reset_password_page.dart';
import '../layouts/shell_layout.dart';

/// Navigator root: dipakai rute di luar shell agar URL ikut berubah saat dibuka dari dalam shell.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Rute yang boleh dibuka tanpa sesi. Selain itu, pengguna diarahkan ke /login dengan `from`.
const _publicPaths = {'/login', '/undangan', '/reset'};

/// Membangun router. Rute tetap dari URL: reload di halaman mana pun kembali ke halaman itu,
/// dan setelah masuk, pengguna dikembalikan ke halaman yang tadi dibuka lewat parameter `from`.
GoRouter buildAppRouter({
  required AppSession session,
  required DocumentsApi documents,
  required ProfileApi? profiles,
}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    // Mulai dari URL yang sedang dibuka di browser, bukan dari '/' (go_router tidak membacanya sendiri di web).
    initialLocation: kIsWeb ? _currentLocation() : null,
    refreshListenable: session,
    redirect: (context, state) => _redirect(session, state),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/dokumen'),
      GoRoute(
        path: '/memuat',
        builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => LoginPage(onLogin: session.signInWith),
      ),
      GoRoute(
        path: '/reset',
        builder: (_, state) => ResetPasswordPage(oobCode: state.uri.queryParameters['oobCode']),
      ),
      GoRoute(
        path: '/undangan',
        builder: (_, _) => const InvitationPage(),
      ),
      GoRoute(
        path: '/profil',
        builder: (_, _) => profiles == null
            ? const SizedBox.shrink()
            : ProfileCompletePage(
                api: profiles,
                email: session.profile?.email ?? '',
                onCompleted: (_) => session.refreshProfile(),
                onLogout: session.signOut,
              ),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/dokumen',
            builder: (_, _) => DocumentsPage(api: documents),
          ),
          GoRoute(
            path: '/akun',
            builder: (_, _) => AccountPage(profile: session.profile, onLogout: session.signOut),
          ),
        ],
      ),
      GoRoute(
        path: '/dokumen/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => DocumentDetailPage(api: documents, documentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/dokumen/:id/tinjau',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => DocumentReviewPage(
          api: documents,
          documentId: state.pathParameters['id']!,
          manual: state.uri.queryParameters['manual'] == '1',
        ),
      ),
      GoRoute(
        path: '/dokumen/:id/proses',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => ProcessingPage(
          api: documents,
          documentId: state.pathParameters['id']!,
          docRef: state.uri.queryParameters['ref'] ?? '',
          pollAfterMs: 2000,
        ),
      ),
    ],
  );
}

String _currentLocation() {
  final uri = Uri.base;
  return uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
}

String? _redirect(AppSession session, GoRouterState state) {
  final path = state.uri.path;
  final here = state.uri.toString();
  final returnTo = state.uri.queryParameters['from'];
  switch (session.status) {
    case SessionStatus.loading:
      // URL tidak diubah selama sesi dipulihkan. Tampilan memuat ditangani di MaterialApp (lihat main.dart).
      return null;
    case SessionStatus.signedOut:
      if (_publicPaths.contains(path)) return null;
      return '/login?from=${Uri.encodeComponent(here)}';
    case SessionStatus.profileIncomplete:
      if (path == '/profil' || path == '/undangan') return null;
      return '/profil?from=${Uri.encodeComponent(here)}';
    case SessionStatus.ready:
      if (path == '/login' || path == '/profil' || path == '/memuat') {
        return returnTo == null || returnTo.isEmpty ? '/dokumen' : returnTo;
      }
      return null;
  }
}
