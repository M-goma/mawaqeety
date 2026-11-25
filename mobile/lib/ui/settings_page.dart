import 'package:flutter/material.dart';

import '../core/methods.dart';
import '../core/prayer_calculator.dart';
import '../core/settings.dart';
import '../main.dart';
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
            Card(
              child: ListTile(
                title: Text(s.place.display, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${s.place.lat.toStringAsFixed(3)}°, ${s.place.lng.toStringAsFixed(3)}° • ${s.place.tz}',
                    textDirection: TextDirection.ltr),
                trailing: const Icon(Icons.edit_location_alt_outlined),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CityPickerPage())),
              ),
            ),
            const _Header('طريقة الحساب', Icons.calculate_outlined),
            Card(
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
            Card(
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
            Card(
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
                _Dropdown<int>(
                  label: 'التذكير قبل الصلاة',
                  value: s.preAlertMinutes,
                  items: const {0: 'بدون تذكير', 5: '5 دقائق', 10: '10 دقائق', 15: '15 دقيقة', 20: '20 دقيقة', 30: '30 دقيقة'},
                  onChanged: (v) => app.update((x) => x.preAlertMinutes = v),
                ),
              ]),
            ),
            const _Header('الأذان', Icons.volume_up_outlined),
            Card(
              child: Column(children: [
                SwitchListTile(
                  title: const Text('تشغيل الأذان عند دخول الوقت والتطبيق مفتوح'),
                  value: s.adhanEnabled,
                  onChanged: (v) => app.update((x) => x.adhanEnabled = v, reschedule: false),
                ),
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
            const _Header('المظهر', Icons.palette_outlined),
            Card(
              child: Column(children: [
                _Dropdown<ThemeChoice>(
                  label: 'الوضع',
                  value: s.theme,
                  items: const {ThemeChoice.dark: 'ليلي', ThemeChoice.light: 'نهاري', ThemeChoice.system: 'حسب الجهاز'},
                  onChanged: (v) => app.update((x) => x.theme = v, reschedule: false),
                ),
                SwitchListTile(title: const Text('نظام 24 ساعة'), value: s.use24h,
                    onChanged: (v) => app.update((x) => x.use24h = v)),
              ]),
            ),
            const _Header('التحديثات', Icons.system_update_outlined),
            const _UpdateCard(),
            const _Header('حول التطبيق', Icons.info_outline),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'مواقيتي – صلاتك في وقتها\n\n'
                  'المواقيت تُحسب على جهازك دون إنترنت بنفس محرك برنامج الكمبيوتر.\n'
                  'نص القرآن الكريم: الرسم العثماني من موسوعة القرآن الكريم (quranenc.com) عبر مشروع quran-json – رخصة CC BY-SA 4.0.\n'
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
      subtitle: Text(v?.nameAr ?? '-', style: const TextStyle(color: AppColors.gold)),
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
                  subtitle: v.fajr ? const Text('أذان الفجر', style: TextStyle(color: AppColors.gold, fontSize: 12)) : null,
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
                leading: const Icon(Icons.location_city, color: AppColors.emerald),
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
  Widget build(BuildContext context) => Card(
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
            if (_status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_status, style: const TextStyle(color: AppColors.gold))),
          ]),
        ),
      );
}
