import 'package:flutter/material.dart';

import '../main.dart';
import '../services/app_updater.dart';
import 'adhkar_page.dart';
import 'prayer_page.dart';
import 'more_page.dart';
import 'quran_pages.dart';
import 'tasbeeh_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await app.notifications.requestPermissions();
      await app.reschedule();
      // Quiet check at startup: offer the update if one is available.
      final r = await app.updater.check(apply: false);
      if (!mounted || r.status != UpdateStatus.available) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 12),
        content: Text(r.message),
        action: SnackBarAction(label: 'تحديث', onPressed: () => app.updater.check()),
      ));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      app.tracker.load(); // a notification button may have logged a prayer meanwhile
      app.reschedule(); // keep the next days scheduled
    }
  }

  @override
  Widget build(BuildContext context) {
    const pages = [PrayerPage(), QuranIndexPage(), AdhkarPage(), TasbeehPage(), MorePage()];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.access_time_outlined), selectedIcon: Icon(Icons.access_time_filled), label: 'المواقيت'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'القرآن'),
          NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'الأذكار'),
          NavigationDestination(icon: Icon(Icons.radio_button_checked_outlined), selectedIcon: Icon(Icons.radio_button_checked), label: 'السبحة'),
          NavigationDestination(icon: Icon(Icons.menu), selectedIcon: Icon(Icons.menu_open), label: 'المزيد'),
        ],
      ),
    );
  }
}
