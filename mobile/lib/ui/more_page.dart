import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'arbaeen_page.dart';
import 'asbab_page.dart';
import 'asma_page.dart';
import 'companions_islam_page.dart';
import 'fiqh_page.dart';
import 'ghazawat_page.dart';
import 'nasab_page.dart';
import 'occasions_page.dart';
import 'quiz_page.dart';
import 'ramadan_page.dart';
import 'seerah_page.dart';
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
    // A band with the group's name, then its tiles two per row.
    Widget band(IconData icon, String title) => Container(
          margin: const EdgeInsets.fromLTRB(14, 18, 14, 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: hero3D(radius: 14),
          child: Row(children: [
            Icon(icon, color: AppColors.goldLight, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ]),
        );
    Widget grid(List<Widget> tiles) => GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: tiles,
        );
    return Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        band(Icons.mosque_outlined, 'السيرة النبوية'),
        grid([
          item('🕌', 'السيرة النبوية', 'من المولد إلى الوفاة على خط زمني', const SeerahPage()),
          item('⚔️', 'غزوات النبي ﷺ', 'بدر وأحد والخندق وفتح مكة…', const GhazawatPage()),
          item('🌳', 'النسب الشريف', 'نسب النبي ﷺ وملتقى أنساب العشرة', const NasabPage()),
          item('🤝', 'كيف أسلم الصحابة', 'قصة إسلام العشرة المبشرين', const CompanionsIslamPage()),
        ]),
        band(Icons.format_quote_outlined, 'الحديث والفقه'),
        grid([
          item('📜', 'الأربعون النووية', 'جوامع الكلم مع فوائدها وتتبّع حفظك', const ArbaeenPage()),
          item('⚖️', 'فقه العبادات', 'من فتاوى إسلام ويب والأزهر ودار الإفتاء', const FiqhPage()),
        ]),
        band(Icons.auto_stories_outlined, 'القرآن والعقيدة'),
        grid([
          item('📖', 'أسباب النزول', 'الصحيحة من البخاري ومسلم، والمكي والمدني', const AsbabPage()),
          item('✨', 'أسماء الله الحسنى', 'تسعة وتسعون اسمًا بمعانيها', const AsmaPage()),
        ]),
        band(Icons.event_note_outlined, 'المواسم والعبادات'),
        grid([
          item('🌙', 'رمضان', 'الصيام والتراويح والتهجد', const RamadanPage()),
          item('🤍', 'الأيام البيض', '١٣ و١٤ و١٥ من كل شهر', const WhiteDaysPage()),
          item('🗓️', 'المناسبات والصيام', 'عرفة وعاشوراء والعيدان والاثنين والخميس', const OccasionsPage()),
          item('💰', 'حاسبة الزكاة', 'المال والذهب والفضة', const ZakatPage()),
        ]),
        band(Icons.emoji_events_outlined, 'تعلّم وتابع تقدّمك'),
        grid([
          item('🏆', 'مسابقات', 'أسئلة قصيرة من محتوى التطبيق بمصادرها', const QuizPage()),
          item('📊', 'إحصائياتي', 'صلواتك وأذكارك ووردك', const StatsPage()),
        ]),
        band(Icons.tune, 'التطبيق'),
        grid([
          item('⚙️', 'الإعدادات', 'المدينة والأذان والألوان', const SettingsPage()),
          guide(),
        ]),
      ]),
    );
  }
}
