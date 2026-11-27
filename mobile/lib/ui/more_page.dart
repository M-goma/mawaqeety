import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'asma_page.dart';
import 'occasions_page.dart';
import 'ramadan_page.dart';
import 'settings_page.dart';
import 'stats_page.dart';
import 'theme.dart';
import 'zakat_page.dart';

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
              padding: EdgeInsets.fromLTRB(6, 12 * UiScale.icon, 6, 10 * UiScale.icon),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(icon, style: TextStyle(fontSize: 34 * UiScale.icon, shadows: const [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 4))])),
                const SizedBox(height: 8),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                const SizedBox(height: 2),
                Text(subtitle, textAlign: TextAlign.center, maxLines: 2, style: TextStyle(fontSize: 11.5, color: Theme.of(context).hintColor)),
              ]),
            ),
          ),
        );
    Widget guide() => Card3D(
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: () => launchUrl(Uri.parse('https://m-goma.github.io/mawaqeety/guide/'), mode: LaunchMode.externalApplication),
            child: Padding(
              padding: EdgeInsets.fromLTRB(6, 12 * UiScale.icon, 6, 10 * UiScale.icon),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('📘', style: TextStyle(fontSize: 34 * UiScale.icon, shadows: const [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 4))])),
                const SizedBox(height: 8),
                const Text('دليل الاستخدام', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                const SizedBox(height: 2),
                Text('شرح مصوّر وفيديو قصير', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: Theme.of(context).hintColor)),
              ]),
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: GridView.count(
        // Small icons: three per row; medium and large: two, shorter tiles.
        crossAxisCount: 2,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.45,
        children: [
          item('📊', 'إحصائياتي', 'صلواتك وأذكارك ووردك', const StatsPage()),
          item('🌙', 'رمضان', 'الصيام والتراويح والتهجد', const RamadanPage()),
          item('🤍', 'الأيام البيض', '١٣ و١٤ و١٥ من كل شهر', const WhiteDaysPage()),
          item('🗓️', 'المناسبات والصيام', 'عرفة وعاشوراء والعيدان والاثنين والخميس', const OccasionsPage()),
          item('✨', 'أسماء الله الحسنى', 'تسعة وتسعون اسمًا بمعانيها', const AsmaPage()),
          item('💰', 'حاسبة الزكاة', 'المال والذهب والفضة', const ZakatPage()),
          item('💾', 'النسخ الاحتياطي', 'احفظ بياناتك واستعدها', const BackupPage()),
          item('⚙️', 'الإعدادات', 'المدينة والأذان والألوان', const SettingsPage()),
          guide(),
        ],
      ),
    );
  }
}
