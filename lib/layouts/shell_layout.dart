import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ShellLayout extends StatefulWidget {
  const ShellLayout({super.key, required this.pages});

  final List<({String label, IconData icon, Widget page})> pages;

  @override
  State<ShellLayout> createState() => _ShellLayoutState();
}

class _ShellLayoutState extends State<ShellLayout> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [for (final p in widget.pages) p.page],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final p in widget.pages)
            NavigationDestination(icon: Icon(p.icon), label: p.label),
        ],
      ),
    );
  }
}

/// Kerangka tab untuk rute bersarang (go_router). Pilihan tab mengikuti lokasi URL, jadi reload tetap di tab yang sama.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _tabs = ['/dokumen', '/akun'];

  @override
  Widget build(BuildContext context) {
    final index = location.startsWith('/akun') ? 1 : 0;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => _go(context, _tabs[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.description_outlined), label: 'Dokumen'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Akun'),
        ],
      ),
    );
  }

  void _go(BuildContext context, String path) {
    // Pindah tab memakai GoRouter agar URL ikut berubah.
    GoRouter.of(context).go(path);
  }
}
