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
    Widget item(String icon, String title, String subtitle, Widget page) => Card3D(
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(icon, style: const TextStyle(fontSize: 38, shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 4))])),
                const SizedBox(height: 8),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                const SizedBox(height: 2),
                Text(subtitle, textAlign: TextAlign.center, maxLines: 2, style: TextStyle(fontSize: 11.5, color: Theme.of(context).hintColor)),
              ]),
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.05,
        children: [
          item('📊', 'إحصائياتي', 'صلواتك وأذكارك ووردك', const StatsPage()),
          item('🐪', 'قصص الأنبياء', '٢٥ قصة بصوتَي نبيل وعرين', const ProphetsPage()),
          item('🧭', 'اتجاه القبلة', 'بوصلة ثلاثية الأبعاد', const QiblaPage()),
          item('⚙️', 'الإعدادات', 'المدينة والأذان والألوان', const SettingsPage()),
        ],
      ),
    );
  }
}
