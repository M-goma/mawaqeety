import 'package:flutter/material.dart';

import 'prophets_page.dart';
import 'qibla_page.dart';
import 'settings_page.dart';
import 'stats_page.dart';
import 'theme.dart';

/// "More" tab: statistics, prophets' stories, Qibla and settings.
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String title, String subtitle, Widget page) => Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(gradient: heroGradient, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16.5)),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: ListView(padding: const EdgeInsets.only(top: 6, bottom: 16), children: [
        item(Icons.insights, 'إحصائياتي', 'صلواتك وأذكارك ووردك، والسلاسل المتتالية', const StatsPage()),
        item(Icons.auto_stories, 'قصص الأنبياء', '٢٥ قصة مسجّلة بصوتَي نبيل وعرين', const ProphetsPage()),
        item(Icons.explore, 'اتجاه القبلة', 'بوصلة ثلاثية الأبعاد', const QiblaPage()),
        item(Icons.settings, 'الإعدادات', 'المدينة، طريقة الحساب، الأذان، الألوان', const SettingsPage()),
      ]),
    );
  }
}
