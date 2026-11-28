import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';

import '../core/arabic.dart';

import '../core/methods.dart';
import '../core/prayer_calculator.dart';
import '../core/settings.dart';
import '../main.dart';
import 'quran_pages.dart' show ReciterTile;
import 'theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.adhan]),
      builder: (context, _) {
        final s = app.settings;
        return Scaffold(
          appBar: AppBar(title: const Text('الإعدادات')),
          body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
            const _Header('الموقع', Icons.place_outlined),
            Card3D(
              child: ListTile(
                title: Text(s.place.display, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${s.place.lat.toStringAsFixed(3)}°, ${s.place.lng.toStringAsFixed(3)}° • ${s.place.tz}',
                    textDirection: TextDirection.ltr),
                trailing: const Icon(Icons.edit_location_alt_outlined),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CityPickerPage())),
              ),
            ),
            const _Header('طريقة الحساب', Icons.calculate_outlined),
            Card3D(
              child: Column(children: [
                _Dropdown<MethodId>(
                  label: 'الطريقة',
                  value: s.method,
                  items: {for (final m in CalculationMethod.all) m.id: m.nameAr},
                  onChanged: (v) => app.update((x) => x.method = v),
                ),
                _Dropdown<AsrMadhab>(
                  label: 'العصر',
                  value: s.madhab,
                  items: const {AsrMadhab.shafii: 'الجمهور (الشافعي والمالكي والحنبلي)', AsrMadhab.hanafi: 'الحنفي'},
                  onChanged: (v) => app.update((x) => x.madhab = v),
                ),
                _Dropdown<HighLatitudeRule>(
                  label: 'خطوط العرض العليا',
                  value: s.highLat,
                  items: const {
                    HighLatitudeRule.angleBased: 'حسب الزاوية (موصى به)',
                    HighLatitudeRule.oneSeventh: 'سُبع الليل',
                    HighLatitudeRule.middleOfNight: 'منتصف الليل',
                    HighLatitudeRule.none: 'بدون',
                  },
                  onChanged: (v) => app.update((x) => x.highLat = v),
                ),
                ListTile(
                  title: const Text('تعديل التاريخ الهجري'),
                  trailing: _Stepper(value: s.hijriAdjust, min: -2, max: 2, onChanged: (v) => app.update((x) => x.hijriAdjust = v)),
                ),
              ]),
            ),
            const _Header('تعديل المواقيت يدويًا (دقائق)', Icons.tune),
            Card3D(
              child: Column(children: [
                for (final p in Prayer.values)
                  ListTile(
                    dense: true,
                    title: Text(p.nameAr),
                    trailing: _Stepper(value: s.adjust[p] ?? 0, min: -30, max: 30, onChanged: (v) => app.update((x) => x.adjust[p] = v)),
                  ),
              ]),
            ),
            const _Header('التنبيهات', Icons.notifications_outlined),
            Card3D(
              child: Column(children: [
                for (final p in Prayer.values)
                  SwitchListTile(
                    dense: true,
                    title: Text('تنبيه ${p.nameAr}'),
                    value: s.notify[p] ?? false,
                    onChanged: (v) => app.update((x) => x.notify[p] = v),
                  ),
                if (Theme.of(context).platform == TargetPlatform.android)
                  SwitchListTile(
                    title: const Text('إشعار دائم بالوقت المتبقي للصلاة القادمة'),
                    subtitle: const Text('عدّاد تنازلي في شريط الإشعارات، بدون صوت', style: TextStyle(fontSize: 12)),
                    value: s.ongoingCountdown,
                    onChanged: (v) => app.update((x) => x.ongoingCountdown = v),
                  ),
                if (Theme.of(context).platform == TargetPlatform.android)
                  SwitchListTile(
                    title: const Text('سؤال «هل صليت؟» بعد كل صلاة'),
                    subtitle: const Text('بعد الأذان بنصف ساعة، تسجّل صلاتك من الإشعار مباشرة لإحصائياتك', style: TextStyle(fontSize: 12)),
                    value: s.prayerCheck,
                    onChanged: (v) => app.update((x) => x.prayerCheck = v),
                  ),
                SwitchListTile(
                  title: const Text('تذكير سورة الكهف يوم الجمعة'),
                  subtitle: const Text('ليلة الجمعة بعد المغرب، وصباح الجمعة، بزر «اقرأ الآن»', style: TextStyle(fontSize: 12)),
                  value: s.fridayKahf,
                  onChanged: (v) => app.update((x) => x.fridayKahf = v),
                ),
                SwitchListTile(
                  title: const Text('تذكير ساعة الاستجابة يوم الجمعة'),
                  subtitle: const Text('قبل المغرب بساعة', style: TextStyle(fontSize: 12)),
                  value: s.fridayHour,
                  onChanged: (v) => app.update((x) => x.fridayHour = v),
                ),
                if (Theme.of(context).platform == TargetPlatform.android)
                  _Dropdown<String>(
                    label: 'شكل الأداة على الشاشة الرئيسية',
                    value: s.widgetStyle,
                    items: const {
                      'clock': 'الساعة + عدّاد بجوار الصلاة القادمة',
                      'cell': 'الساعة + عدّاد داخل خانة الصلاة',
                      'countdown': 'عدّاد كبير (الشكل السابق)',
                    },
                    onChanged: (v) async {
                      await app.update((x) => x.widgetStyle = v, reschedule: false);
                      await app.widgets.update(app);
                    },
                  ),
                _Dropdown<int>(
                  label: 'التذكير قبل الصلاة',
                  value: s.preAlertMinutes,
                  items: const {0: 'بدون تذكير', 5: '5 دقائق', 10: '10 دقائق', 15: '15 دقيقة', 20: '20 دقيقة', 30: '30 دقيقة'},
                  onChanged: (v) => app.update((x) => x.preAlertMinutes = v),
                ),
              ]),
            ),
            const _Header('الأذان', Icons.volume_up_outlined),
            Card3D(
              child: Column(children: [
                SwitchListTile(
                  title: Text(Theme.of(context).platform == TargetPlatform.android ? 'الأذان أو التنبيه الصوتي في وقت كل صلاة' : 'تشغيل الأذان عند دخول الوقت والتطبيق مفتوح'),
                  subtitle: Theme.of(context).platform == TargetPlatform.android
                      ? const Text('حتى لو كان التطبيق مغلقًا. لا يقطع تلاوة أو إذاعة تستمع إليها', style: TextStyle(fontSize: 12))
                      : null,
                  value: s.adhanEnabled,
                  // Android: re-plan the native adhans.
                  onChanged: (v) => app.update((x) => x.adhanEnabled = v),
                ),
                // What plays at prayer time: the full adhan or Mazen's short spoken alert.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text('عند دخول وقت الصلاة', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'full', icon: Icon(Icons.mosque_outlined), label: Text('الأذان كاملًا')),
                        ButtonSegment(value: 'voice', icon: Icon(Icons.record_voice_over_outlined), label: Text('تنبيه صوتي')),
                      ],
                      selected: {s.adhanMode},
                      onSelectionChanged: s.adhanEnabled ? (v) => app.update((x) => x.adhanMode = v.first) : null,
                    ),
                    if (s.adhanMode == 'voice') ...[
                      const SizedBox(height: 8),
                      Text(
                        s.preAlertMinutes > 0
                            ? 'بصوت مازن: «اقتربت صلاة الظهر» قبل الوقت بـ${Arabic.minutes(s.preAlertMinutes)}، ثم «حان الآن موعد صلاة الظهر» عند دخوله.'
                            : 'بصوت مازن: «حان الآن موعد صلاة الظهر» عند دخول الوقت. اضبط «التذكير قبل الصلاة» ليقول أيضًا «اقتربت صلاة الظهر».',
                        style: TextStyle(fontSize: 12.5, height: 1.6, color: Theme.of(context).hintColor),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          icon: const Icon(Icons.play_circle_outline),
                          label: const Text('استمع للتنبيه'),
                          onPressed: () async {
                            await app.adhan.playAlert(Prayer.dhuhr, near: true);
                            await Future.delayed(const Duration(milliseconds: 2600));
                            await app.adhan.playAlert(Prayer.dhuhr, near: false);
                          },
                        ),
                      ),
                    ],
                  ]),
                ),
                if (Theme.of(context).platform == TargetPlatform.android) ...[
                  SwitchListTile(
                    secondary: const Icon(Icons.volume_off_outlined),
                    title: const Text('الأذان حتى والهاتف صامت'),
                    subtitle: const Text('يعمل بصوت المنبّه؛ اضبط مستواه من إعدادات الصوت', style: TextStyle(fontSize: 12)),
                    value: s.adhanSilent,
                    onChanged: s.adhanEnabled ? (v) => app.update((x) => x.adhanSilent = v) : null,
                  ),
                  SwitchListTile(
                    secondary: const Text('📱', style: TextStyle(fontSize: 22)),
                    title: const Text('إسكات الأذان بقلب الهاتف على وجهه'),
                    value: s.adhanFlip,
                    onChanged: s.adhanEnabled ? (v) => app.update((x) => x.adhanFlip = v) : null,
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.power_settings_new),
                    title: const Text('إسكات الأذان بزر التشغيل (Power)'),
                    value: s.adhanPower,
                    onChanged: s.adhanEnabled ? (v) => app.update((x) => x.adhanPower = v) : null,
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.menu_book_outlined),
                    title: const Text('قلب الهاتف يوقف التلاوة والقصص والإذاعة'),
                    subtitle: const Text('زر التشغيل لا يوقفها، لتستمع والشاشة مطفأة', style: TextStyle(fontSize: 12)),
                    value: s.flipStopsAudio,
                    onChanged: (v) => app.update((x) => x.flipStopsAudio = v, reschedule: false),
                  ),
                ],
                _VoiceTile(label: 'صوت الأذان', id: s.adhanId, fajr: false,
                    onChanged: (v) => app.update((x) => x.adhanId = v, reschedule: false)),
                _VoiceTile(label: 'أذان الفجر', id: s.fajrAdhanId, fajr: true,
                    onChanged: (v) => app.update((x) => x.fajrAdhanId = v, reschedule: false)),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                      'يصل إشعار بنغمة قصيرة عند دخول كل صلاة حتى لو كان التطبيق مغلقًا. اضغط على الإشعار لسماع الأذان كاملًا. '
                      'أنظمة الهواتف لا تسمح بتشغيل صوت إشعار أطول من 30 ثانية.',
                      style: TextStyle(fontSize: 12)),
                ),
              ]),
            ),
            const _Header('التلاوة', Icons.record_voice_over_outlined),
            const ReciterTile(margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6)),
            const _Header('المظهر', Icons.palette_outlined),
            Card3D(
              child: Column(children: [
                _Dropdown<ThemeChoice>(
                  label: 'الوضع',
                  value: s.theme,
                  items: const {ThemeChoice.dark: 'ليلي', ThemeChoice.light: 'نهاري', ThemeChoice.system: 'حسب الجهاز'},
                  onChanged: (v) => app.update((x) => x.theme = v, reschedule: false),
                ),
                _PalettePicker(
                  selected: s.palette,
                  onChanged: (id) => app.update((x) => x.palette = id, reschedule: false).then((_) => app.widgets.update(app)),
                ),
                SwitchListTile(title: const Text('نظام 24 ساعة'), value: s.use24h,
                    onChanged: (v) => app.update((x) => x.use24h = v)),
              ]),
            ),
            Card3D(
              child: ListTile(
                title: const Text('حجم العرض (الخط والأيقونات والبطاقات)'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('صغير')),
                      ButtonSegment(value: 1, label: Text('متوسط')),
                      ButtonSegment(value: 2, label: Text('كبير')),
                    ],
                    selected: {s.iconSize},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => app.update((x) => x.iconSize = v.first, reschedule: false),
                  ),
                ),
              ),
            ),
            const _Header('النسخ الاحتياطي', Icons.backup_outlined),
            Card3D(
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('حفظ نسخة احتياطية'),
                  subtitle: const Text('إحصائياتك وإعداداتك في ملف واحد، احفظه أو أرسله لنفسك', style: TextStyle(fontSize: 12)),
                  onTap: () => exportBackup(context),
                ),
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: const Text('استعادة نسخة احتياطية'),
                  subtitle: const Text('من ملف حفظته من قبل (يستبدل البيانات الحالية)', style: TextStyle(fontSize: 12)),
                  onTap: () => importBackup(context),
                ),
              ]),
            ),
            const _Header('التحديثات', Icons.system_update_outlined),
            const _UpdateCard(),
            const _Header('حول التطبيق', Icons.info_outline),
            const Card3D(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'سبيل – رفيق المسلم (من مواقيتي)\n\n'
                  'المواقيت تُحسب على جهازك دون إنترنت بنفس محرك برنامج الكمبيوتر.\n'
                  'نص القرآن الكريم: الرسم العثماني من موسوعة القرآن الكريم (quranenc.com) عبر مشروع quran-json – رخصة CC BY-SA 4.0.\n'
                  'صفحات المصحف: مصحف المدينة النبوية (رواية حفص) من مجمع الملك فهد لطباعة المصحف الشريف، عبر مشروع Quran-PNG على GitHub.\n'
                  'خط المصحف: Amiri Quran (OFL). تسجيلات الأذان من مجموعة عامة على GitHub وحقوقها لأصحابها.\n'
                  'قصص الأنبياء مستندة إلى القرآن الكريم والسنة الصحيحة؛ نرحب بملاحظات أهل العلم.',
                  style: TextStyle(height: 1.7, fontSize: 13),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Header(this.text, this.icon);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
        child: Row(children: [
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
      );
}

class _Dropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;
  const _Dropdown({required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(label),
        subtitle: DropdownButton<T>(
          isExpanded: true,
          value: items.containsKey(value) ? value : items.keys.first,
          underline: const SizedBox.shrink(),
          items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      );
}

class _Stepper extends StatelessWidget {
  final int value, min, max;
  final ValueChanged<int> onChanged;
  const _Stepper({required this.value, required this.min, required this.max, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: value > min ? () => onChanged(value - 1) : null),
        SizedBox(width: 32, child: Text(value > 0 ? '+$value' : '$value', textAlign: TextAlign.center, textDirection: TextDirection.ltr)),
        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: value < max ? () => onChanged(value + 1) : null),
      ]);
}

class _VoiceTile extends StatelessWidget {
  final String label, id;
  final bool fajr;
  final ValueChanged<String> onChanged;
  const _VoiceTile({required this.label, required this.id, required this.fajr, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final v = app.repo.voice(id);
    final playing = app.adhan.playingId == id;
    return ListTile(
      title: Text(label),
      subtitle: Text(v?.nameAr ?? '-', style: TextStyle(color: AppColors.gold)),
      onTap: () async {
        final picked = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => VoicePickerPage(selected: id, fajrFirst: fajr)));
        if (picked != null) onChanged(picked);
      },
      trailing: IconButton(
        icon: Icon(playing ? Icons.stop_circle_outlined : Icons.play_circle_outline, color: AppColors.emerald),
        onPressed: v == null ? null : () => playing ? app.adhan.stop() : app.adhan.play(v),
      ),
    );
  }
}

class VoicePickerPage extends StatefulWidget {
  final String selected;
  final bool fajrFirst;
  const VoicePickerPage({super.key, required this.selected, required this.fajrFirst});
  @override
  State<VoicePickerPage> createState() => _VoicePickerPageState();
}

class _VoicePickerPageState extends State<VoicePickerPage> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    var voices = app.repo.voices.toList();
    if (widget.fajrFirst) voices = [...voices.where((v) => v.fajr), ...voices.where((v) => !v.fajr)];
    if (_q.isNotEmpty) voices = voices.where((v) => v.nameAr.contains(_q)).toList();
    return ListenableBuilder(
      listenable: app.adhan,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(widget.fajrFirst ? 'اختيار أذان الفجر' : 'اختيار صوت الأذان')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(decoration: const InputDecoration(hintText: 'ابحث باسم المؤذن', prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _q = v.trim())),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: voices.length,
              itemBuilder: (c, i) {
                final v = voices[i];
                final playing = app.adhan.playingId == v.id;
                return ListTile(
                  leading: Icon(v.id == widget.selected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: v.id == widget.selected ? AppColors.emerald : null),
                  title: Text(v.nameAr),
                  subtitle: v.fajr ? Text('أذان الفجر', style: TextStyle(color: AppColors.gold, fontSize: 12)) : null,
                  trailing: IconButton(
                    icon: Icon(playing ? Icons.stop_circle_outlined : Icons.play_circle_outline),
                    onPressed: () => playing ? app.adhan.stop() : app.adhan.play(v),
                  ),
                  onTap: () {
                    app.adhan.stop();
                    Navigator.pop(context, v.id);
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class CityPickerPage extends StatefulWidget {
  const CityPickerPage({super.key});
  @override
  State<CityPickerPage> createState() => _CityPickerPageState();
}

class _CityPickerPageState extends State<CityPickerPage> {
  String _q = '';
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final List<Place> results = app.repo.searchCities(_q);
    return Scaffold(
      appBar: AppBar(title: const Text('اختيار المدينة')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            onPressed: _busy
                ? null
                : () async {
                    setState(() { _busy = true; _error = null; });
                    final err = await app.detectLocation();
                    if (!context.mounted) return;
                    setState(() { _busy = false; _error = err; });
                    if (err == null) Navigator.pop(context);
                  },
            icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location),
            label: const Text('تحديد موقعي تلقائيًا'),
          ),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(hintText: 'ابحث عن مدينة أو دولة', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (c, i) {
              final p = results[i];
              return ListTile(
                leading: Icon(Icons.location_city, color: AppColors.emerald),
                title: Text(p.nameAr),
                subtitle: Text(p.countryAr),
                trailing: Text(p.nameEn, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                onTap: () async {
                  await app.setPlace(p);
                  if (context.mounted) Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _UpdateCard extends StatefulWidget {
  const _UpdateCard();
  @override
  State<_UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<_UpdateCard> {
  String _version = '';
  String _status = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    app.updater.versionLabel().then((v) {
      if (mounted) setState(() => _version = v);
    });
  }

  @override
  Widget build(BuildContext context) => Card3D(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('الإصدار الحالي: $_version', textDirection: TextDirection.rtl),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() { _busy = true; _status = 'جارٍ البحث عن تحديثات...'; });
                      final r = await app.updater.check();
                      if (mounted) setState(() { _busy = false; _status = r.message; });
                    },
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.system_update),
              label: const Text('البحث عن تحديثات'),
            ),
            if (_status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_status, style: TextStyle(color: AppColors.gold))),
          ]),
        ),
      );
}


/// Ten colour styles shown as tappable swatches.
class _PalettePicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _PalettePicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final current = paletteById(selected);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('الألوان', style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(current.nameAr, style: TextStyle(color: AppColors.gold)),
        ]),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final p in palettes)
              Tooltip(
                message: p.nameAr,
                child: InkWell(
                  borderRadius: BorderRadius.circular(40),
                  onTap: () => onChanged(p.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [p.primary, p.hero[1], p.bg],
                          begin: Alignment.topRight, end: Alignment.bottomLeft),
                      border: Border.all(color: p.id == selected ? p.accent : Colors.white24, width: p.id == selected ? 3 : 1),
                    ),
                    child: Center(
                      child: p.id == selected
                          ? Icon(Icons.check, color: p.accent, size: 22)
                          : Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: p.accent)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ]),
    );
  }
}

Future<void> exportBackup(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final now = DateTime.now();
    final name = 'sabeel-backup-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.json';
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(utf8.encode(app.exportBackup()), mimeType: 'application/json', name: name)],
      fileNameOverrides: [name],
      subject: 'نسخة احتياطية من سبيل',
    ));
  } catch (e) {
    messenger.showSnackBar(const SnackBar(content: Text('تعذّر حفظ النسخة')));
  }
}

Future<void> importBackup(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final picked = await FilePicker.pickFiles(type: FileType.any);
  if (picked.isEmpty) return;
  final bytes = await picked.first.readAsBytes();
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('استعادة النسخة؟'),
      content: const Text('ستُستبدل إحصائياتك وإعداداتك الحالية ببيانات الملف.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('استعادة')),
      ],
    ),
  );
  if (ok != true) return;
  final done = await app.importBackup(utf8.decode(bytes, allowMalformed: true));
  messenger.showSnackBar(SnackBar(content: Text(done ? 'تمت الاستعادة' : 'هذا الملف ليس نسخة احتياطية من سبيل')));
}


/// النسخ الاحتياطي as its own page (from «المزيد»).
class BackupPage extends StatelessWidget {
  const BackupPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('النسخ الاحتياطي')),
        body: ListView(padding: const EdgeInsets.only(top: 8), children: [
          Card3D(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('حفظ نسخة احتياطية'),
                subtitle: const Text('إحصائياتك وإعداداتك في ملف واحد، احفظه أو أرسله لنفسك', style: TextStyle(fontSize: 12)),
                onTap: () => exportBackup(context),
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('استعادة نسخة احتياطية'),
                subtitle: const Text('من ملف حفظته من قبل (يستبدل البيانات الحالية)', style: TextStyle(fontSize: 12)),
                onTap: () => importBackup(context),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('احفظ نسخة قبل تغيير هاتفك أو حذف التطبيق، ثم استعدها على الهاتف الجديد.',
                style: TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor, height: 1.6)),
          ),
        ]),
      );
}
